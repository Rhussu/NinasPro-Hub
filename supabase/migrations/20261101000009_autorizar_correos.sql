-- =============================================================================
-- Migration: 20261101000009_autorizar_correos.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Autorización de correos desde la app (vista "Accesos", US-04).
--
-- Las autorizaciones se crean solo con la RPC autorizar_correo, que valida los
-- privilegios de quien autoriza y, si no los tiene, registra el intento en
-- auditoria_seguridad y responde 403 (US-04 escenario 3). Para que ningún
-- intento se salte la auditoría se quita el INSERT directo sobre la tabla.
--   - Directiva: cualquier rol y sede (incluida la líder de sede).
--   - Equipo de Gestión: solo alumnas inscritas en su sede.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. LÍDER DE SEDE (US-04: "tutora, líder de sede o comunicación")
-- -----------------------------------------------------------------------------
ALTER TABLE public.correos_autorizados
  ADD COLUMN es_lider_sede BOOLEAN NOT NULL DEFAULT false,
  ADD CONSTRAINT correos_autorizados_lider_gestion CHECK (NOT es_lider_sede OR rol = 'equipo_gestion');

CREATE OR REPLACE FUNCTION public.crear_perfil_desde_autorizacion()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_aut public.correos_autorizados;
  v_alumna public.alumnas;
BEGIN
  v_aut := public.autorizacion_vigente(NEW.email);

  -- Defensa en profundidad: el hook ya debió rechazar este registro
  IF v_aut.id IS NULL THEN
    RAISE EXCEPTION 'El correo % no tiene una autorización vigente', NEW.email
      USING ERRCODE = '42501';
  END IF;

  IF v_aut.rol = 'alumna' THEN
    SELECT * INTO v_alumna FROM public.alumnas WHERE id = v_aut.alumna_id;

    INSERT INTO public.perfiles (id, rut, nombres, apellidos, correo, rol)
    VALUES (NEW.id, v_alumna.rut, v_alumna.nombres, v_alumna.apellidos, v_aut.correo, 'alumna');

    UPDATE public.alumnas
    SET perfil_usuario_id = NEW.id,
        correo = coalesce(correo, v_aut.correo),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_aut.alumna_id;
  ELSE
    INSERT INTO public.perfiles (id, rut, nombres, apellidos, correo, rol)
    VALUES (NEW.id, v_aut.rut, v_aut.nombres, v_aut.apellidos, v_aut.correo, v_aut.rol);
  END IF;

  IF v_aut.sede_id IS NOT NULL THEN
    INSERT INTO public.usuarios_sedes (perfil_id, sede_id, es_lider_sede)
    VALUES (NEW.id, v_aut.sede_id, v_aut.es_lider_sede)
    ON CONFLICT (perfil_id, sede_id) DO UPDATE SET es_lider_sede = excluded.es_lider_sede;
  END IF;

  UPDATE public.correos_autorizados
  SET usado_en = timezone('utc'::text, now())
  WHERE id = v_aut.id;

  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. SOLO SE AUTORIZA CON LA RPC (auditada)
-- -----------------------------------------------------------------------------
DROP POLICY correos_autorizados_insert ON public.correos_autorizados;
REVOKE INSERT, UPDATE ON public.correos_autorizados FROM anon, authenticated;

-- Error de validación: HTTP 400 con un mensaje listo para mostrar
CREATE OR REPLACE FUNCTION public.autorizar_correo(
  p_correo text,
  p_rol public.rol_usuario,
  p_sede_id uuid DEFAULT NULL,
  p_alumna_id uuid DEFAULT NULL,
  p_rut text DEFAULT NULL,
  p_nombres text DEFAULT NULL,
  p_apellidos text DEFAULT NULL,
  p_es_lider_sede boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_actor public.rol_usuario := public.current_user_role();
  v_correo text := lower(btrim(coalesce(p_correo, '')));
  v_alumna public.alumnas;
  v_permitido boolean;
  v_fila public.correos_autorizados;
BEGIN
  -- Privilegios: Directiva todo; Gestión solo alumnas inscritas en una sede que gestiona
  v_permitido := v_actor = 'directorio'
    OR (
      v_actor = 'equipo_gestion'
      AND p_rol = 'alumna'
      AND p_sede_id IS NOT NULL
      AND public.gestiona_sede(p_sede_id)
    );

  IF NOT coalesce(v_permitido, false) THEN
    PERFORM public.registrar_evento_seguridad(
      'autorizacion_denegada',
      auth.uid(),
      v_correo,
      jsonb_build_object(
        'rol_actor', v_actor,
        'rol_solicitado', p_rol,
        'sede_id', p_sede_id,
        'alumna_id', p_alumna_id
      )
    );
    -- Se responde 403 sin lanzar una excepción para que el registro de auditoría se confirme
    PERFORM set_config('response.status', '403', true);
    RETURN jsonb_build_object(
      'code', '42501',
      'message', 'No tienes permiso para autorizar este acceso. El intento quedó registrado.'
    );
  END IF;

  IF v_correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'Revisa el formato del correo.';
  END IF;

  IF p_rol = 'alumna' THEN
    IF p_alumna_id IS NULL OR p_sede_id IS NULL THEN
      RAISE EXCEPTION 'Elige la alumna y su sede.';
    END IF;
    SELECT * INTO v_alumna FROM public.alumnas WHERE id = p_alumna_id;
    IF v_alumna.id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.inscripciones i
      JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
      WHERE i.alumna_id = p_alumna_id AND ic.sede_id = p_sede_id
    ) THEN
      RAISE EXCEPTION 'La alumna no está inscrita en esa sede.';
    END IF;
    IF v_alumna.perfil_usuario_id IS NOT NULL THEN
      RAISE EXCEPTION 'La alumna ya tiene una cuenta.';
    END IF;
  ELSE
    IF v_correo NOT LIKE '%@ninaspro.cl' THEN
      RAISE EXCEPTION 'El voluntariado usa su correo institucional @ninaspro.cl.';
    END IF;
    IF nullif(btrim(p_rut), '') IS NULL OR nullif(btrim(p_nombres), '') IS NULL OR nullif(btrim(p_apellidos), '') IS NULL THEN
      RAISE EXCEPTION 'Completa el RUT, los nombres y los apellidos.';
    END IF;
    IF p_rol <> 'directorio' AND p_sede_id IS NULL THEN
      RAISE EXCEPTION 'Elige la sede.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.perfiles WHERE rut = btrim(p_rut)) THEN
      RAISE EXCEPTION 'Ya existe una cuenta con el RUT %.', btrim(p_rut);
    END IF;
  END IF;

  IF p_es_lider_sede AND p_rol <> 'equipo_gestion' THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión puede liderar una sede.';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_correo) THEN
    RAISE EXCEPTION 'Ya existe una cuenta con el correo %.', v_correo;
  END IF;

  -- Una autorización pendiente vencida se reemplaza; una vigente no
  DELETE FROM public.correos_autorizados
  WHERE correo = v_correo AND usado_en IS NULL AND expira_en <= timezone('utc'::text, now());
  IF EXISTS (SELECT 1 FROM public.correos_autorizados WHERE correo = v_correo AND usado_en IS NULL) THEN
    RAISE EXCEPTION 'El correo % ya tiene una autorización pendiente.', v_correo;
  END IF;

  INSERT INTO public.correos_autorizados
    (correo, rol, sede_id, alumna_id, rut, nombres, apellidos, es_lider_sede, autorizado_por)
  VALUES (
    v_correo,
    p_rol,
    CASE WHEN p_rol = 'directorio' THEN NULL ELSE p_sede_id END,
    CASE WHEN p_rol = 'alumna' THEN p_alumna_id END,
    CASE WHEN p_rol = 'alumna' THEN NULL ELSE btrim(p_rut) END,
    CASE WHEN p_rol = 'alumna' THEN NULL ELSE btrim(p_nombres) END,
    CASE WHEN p_rol = 'alumna' THEN NULL ELSE btrim(p_apellidos) END,
    coalesce(p_es_lider_sede, false),
    auth.uid()
  )
  RETURNING * INTO v_fila;

  RETURN to_jsonb(v_fila);
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. ALUMNAS QUE AÚN NO TIENEN CUENTA (para elegir en la vista "Accesos")
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.alumnas_para_autorizar()
RETURNS TABLE (
  id uuid,
  rut varchar,
  nombres varchar,
  apellidos varchar,
  correo varchar,
  sede_id uuid,
  sede_nombre varchar
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT DISTINCT ON (a.id) a.id, a.rut, a.nombres, a.apellidos, a.correo, s.id, s.nombre
  FROM public.alumnas a
  JOIN public.inscripciones i ON i.alumna_id = a.id
  JOIN public.instancias_curso ic ON ic.id = i.instancia_curso_id
  JOIN public.sedes s ON s.id = ic.sede_id
  WHERE a.perfil_usuario_id IS NULL
    AND public.gestiona_sede(s.id)
    AND NOT EXISTS (
      SELECT 1 FROM public.correos_autorizados ca
      WHERE ca.alumna_id = a.id AND ca.usado_en IS NULL AND ca.expira_en > timezone('utc'::text, now())
    )
  ORDER BY a.id, i.fecha_inscripcion DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.autorizar_correo(text, public.rol_usuario, uuid, uuid, text, text, text, boolean) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.alumnas_para_autorizar() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.autorizar_correo(text, public.rol_usuario, uuid, uuid, text, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.alumnas_para_autorizar() TO authenticated;
