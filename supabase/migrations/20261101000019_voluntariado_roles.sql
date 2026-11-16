-- =============================================================================
-- Migration: 20261101000019_voluntariado_roles.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Voluntariado y roles semanales de las tutoras (US-30..32, US-43, US-44).
--
--   - La ficha del voluntariado existe antes que la cuenta: guarda su RUT,
--     nombre, correo institucional, rol y sede. Al cargarla se autoriza su
--     correo; cuando crea su cuenta, la ficha queda vinculada por el RUT.
--   - Solo la Directiva carga fichas (masiva o individual), registra la
--     adhesión, cambia el rol, registra la salida y asigna a cursos.
--   - La salida desactiva la cuenta y quita sus roles de clases posteriores;
--     la trayectoria (cursos) se conserva.
--   - Gestión de la sede asigna los roles de cada clase: una tutora puede
--     tener 0, 1, 2 o más roles en la misma clase. La tutora marca el
--     cumplimiento de los suyos y Gestión el de cualquiera.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FICHA DEL VOLUNTARIADO INDEPENDIENTE DE LA CUENTA (US-30)
-- -----------------------------------------------------------------------------
ALTER TABLE public.voluntarios_detalle
  ALTER COLUMN perfil_id DROP NOT NULL,
  ADD COLUMN rut VARCHAR(12),
  ADD COLUMN nombres VARCHAR(100),
  ADD COLUMN apellidos VARCHAR(100),
  ADD COLUMN correo VARCHAR(150),
  ADD COLUMN telefono VARCHAR(20),
  ADD COLUMN rol public.rol_usuario NOT NULL DEFAULT 'tutora',
  ADD COLUMN sede_id UUID REFERENCES public.sedes(id) ON DELETE RESTRICT;

-- Fichas existentes: los datos vienen de su cuenta y su primera sede
UPDATE public.voluntarios_detalle v
SET rut = public.formatear_rut(p.rut),
    nombres = p.nombres,
    apellidos = p.apellidos,
    correo = lower(p.correo),
    telefono = p.telefono,
    rol = CASE WHEN p.rol = 'equipo_gestion' THEN 'equipo_gestion' ELSE 'tutora' END::public.rol_usuario,
    sede_id = (
      SELECT us.sede_id FROM public.usuarios_sedes us
      WHERE us.perfil_id = p.id ORDER BY us.asignado_en, us.id LIMIT 1
    )
FROM public.perfiles p
WHERE p.id = v.perfil_id;

ALTER TABLE public.voluntarios_detalle
  ALTER COLUMN rut SET NOT NULL,
  ALTER COLUMN nombres SET NOT NULL,
  ALTER COLUMN apellidos SET NOT NULL,
  ALTER COLUMN correo SET NOT NULL,
  ADD CONSTRAINT voluntarios_detalle_rol_voluntariado CHECK (rol IN ('tutora', 'equipo_gestion')),
  ADD CONSTRAINT voluntarios_detalle_correo_normalizado CHECK (correo = lower(btrim(correo)));

CREATE UNIQUE INDEX voluntarios_detalle_rut_normalizado ON public.voluntarios_detalle (public.normalizar_rut(rut));
CREATE UNIQUE INDEX voluntarios_detalle_correo_unico ON public.voluntarios_detalle (correo);

-- Una ficha insertada solo con su cuenta toma los datos del perfil
CREATE OR REPLACE FUNCTION public.completar_ficha_voluntaria()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_perfil public.perfiles;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := timezone('utc'::text, now());
  END IF;
  IF NEW.perfil_id IS NOT NULL AND (NEW.rut IS NULL OR NEW.nombres IS NULL OR NEW.apellidos IS NULL OR NEW.correo IS NULL) THEN
    SELECT * INTO v_perfil FROM public.perfiles WHERE id = NEW.perfil_id;
    NEW.rut := coalesce(NEW.rut, public.formatear_rut(v_perfil.rut));
    NEW.nombres := coalesce(NEW.nombres, v_perfil.nombres);
    NEW.apellidos := coalesce(NEW.apellidos, v_perfil.apellidos);
    NEW.correo := coalesce(NEW.correo, lower(v_perfil.correo));
    NEW.telefono := coalesce(NEW.telefono, v_perfil.telefono);
    IF TG_OP = 'INSERT' AND v_perfil.rol = 'equipo_gestion' THEN
      NEW.rol := 'equipo_gestion';
    END IF;
    NEW.sede_id := coalesce(NEW.sede_id, (
      SELECT us.sede_id FROM public.usuarios_sedes us
      WHERE us.perfil_id = NEW.perfil_id ORDER BY us.asignado_en, us.id LIMIT 1
    ));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER voluntarios_detalle_completar
  BEFORE INSERT OR UPDATE ON public.voluntarios_detalle
  FOR EACH ROW EXECUTE FUNCTION public.completar_ficha_voluntaria();

-- -----------------------------------------------------------------------------
-- 2. AL CREAR LA CUENTA, LA FICHA QUEDA VINCULADA POR EL RUT
-- -----------------------------------------------------------------------------
-- Igual que en la migración 09, más el vínculo con la ficha del voluntariado.
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
    INSERT INTO public.perfiles (id, rut, nombres, apellidos, correo, rol, telefono)
    VALUES (
      NEW.id, v_aut.rut, v_aut.nombres, v_aut.apellidos, v_aut.correo, v_aut.rol,
      (SELECT v.telefono FROM public.voluntarios_detalle v
       WHERE public.normalizar_rut(v.rut) = public.normalizar_rut(v_aut.rut))
    );

    UPDATE public.voluntarios_detalle
    SET perfil_id = NEW.id
    WHERE public.normalizar_rut(rut) = public.normalizar_rut(v_aut.rut) AND perfil_id IS NULL;
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
-- 3. PERMISOS DE LECTURA Y ESCRITURA
-- -----------------------------------------------------------------------------
-- La Directiva ve todas las fichas; Gestión y las tutoras, las de quienes
-- comparten su sede. Nadie escribe directo: todo pasa por las RPC.
DROP POLICY voluntarios_select ON public.voluntarios_detalle;
DROP POLICY voluntarios_write ON public.voluntarios_detalle;
CREATE POLICY voluntarios_select ON public.voluntarios_detalle FOR SELECT TO authenticated
  USING (
    public.is_directorio()
    OR (perfil_id = auth.uid() AND public.current_user_role() IS NOT NULL)
    OR (perfil_id IS NOT NULL AND public.perfil_en_mis_sedes(perfil_id))
  );
REVOKE INSERT, UPDATE, DELETE ON public.voluntarios_detalle FROM anon, authenticated;

-- Asignar tutoras a cursos: solo la Directiva, con la RPC (US-31)
DROP POLICY tutores_instancia_write ON public.tutores_instancia;
REVOKE INSERT, UPDATE, DELETE ON public.tutores_instancia FROM anon, authenticated;

-- Roles de cada clase: con las RPC de Gestión y de la tutora (US-43, US-44)
DROP POLICY tareas_insert ON public.tareas_semanales_tutores;
DROP POLICY tareas_update ON public.tareas_semanales_tutores;
DROP POLICY tareas_delete ON public.tareas_semanales_tutores;
REVOKE INSERT, UPDATE, DELETE ON public.tareas_semanales_tutores FROM anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. AUXILIARES
-- -----------------------------------------------------------------------------
-- 'Tutora', 'Equipo de Gestión', 'gestion'... -> rol; NULL si no se reconoce
CREATE OR REPLACE FUNCTION public.rol_voluntariado(p_texto text)
RETURNS public.rol_usuario
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT CASE public.clave_nombre(coalesce(p_texto, ''))
    WHEN '' THEN 'tutora'
    WHEN 'tutora' THEN 'tutora'
    WHEN 'tutor' THEN 'tutora'
    WHEN 'equipogestion' THEN 'equipo_gestion'
    WHEN 'equipodegestion' THEN 'equipo_gestion'
    WHEN 'gestion' THEN 'equipo_gestion'
  END::public.rol_usuario;
$$;

CREATE OR REPLACE FUNCTION public.ficha_voluntaria(p_id uuid)
RETURNS public.voluntarios_detalle
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  SELECT * INTO v_ficha FROM public.voluntarios_detalle WHERE id = p_id;
  IF v_ficha.id IS NULL THEN
    RAISE EXCEPTION 'La ficha de voluntariado no existe.' USING ERRCODE = '22023';
  END IF;
  RETURN v_ficha;
END;
$$;

-- Autoriza el correo de una ficha sin cuenta (si no tiene ya una autorización vigente)
CREATE OR REPLACE FUNCTION public.autorizar_correo_voluntaria(p_ficha public.voluntarios_detalle)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_expira timestamptz;
BEGIN
  IF p_ficha.perfil_id IS NOT NULL OR p_ficha.sede_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = p_ficha.correo) THEN
    RAISE EXCEPTION 'Ya existe una cuenta con el correo %.', p_ficha.correo USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.correos_autorizados
  WHERE correo = p_ficha.correo AND usado_en IS NULL AND expira_en <= timezone('utc'::text, now());

  SELECT expira_en INTO v_expira FROM public.correos_autorizados
  WHERE correo = p_ficha.correo AND usado_en IS NULL;
  IF v_expira IS NOT NULL THEN
    RETURN v_expira;
  END IF;

  INSERT INTO public.correos_autorizados (correo, rol, sede_id, rut, nombres, apellidos, autorizado_por)
  VALUES (p_ficha.correo, p_ficha.rol, p_ficha.sede_id, p_ficha.rut, p_ficha.nombres, p_ficha.apellidos, auth.uid())
  RETURNING expira_en INTO v_expira;
  RETURN v_expira;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. CARGA MASIVA E INDIVIDUAL DE FICHAS (US-30)
-- -----------------------------------------------------------------------------
-- Cada fila: rut, nombres, apellidos, correo, telefono, institucion, rol y
-- fecha_ingreso (ISO, opcional). Las filas válidas se cargan y las inválidas
-- se devuelven con su motivo (US-30 escenario 1). Con p_solo_validar no se
-- escribe nada (vista previa). Un RUT que ya tiene ficha la conserva y suma
-- la sede (US-30 escenario 2); si estaba retirada, se reincorpora.
CREATE OR REPLACE FUNCTION public.importar_voluntarias(
  p_sede_id uuid,
  p_filas jsonb,
  p_solo_validar boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_resultado jsonb := '[]'::jsonb;
  v_fila jsonb;
  v_num int;
  v_errores text[];
  v_estado text;
  v_motivo text;
  v_rut text;
  v_nombres text;
  v_apellidos text;
  v_correo text;
  v_telefono text;
  v_institucion text;
  v_rol_txt text;
  v_rol public.rol_usuario;
  v_fecha_txt text;
  v_fecha date;
  v_ficha public.voluntarios_detalle;
  v_perfil public.perfiles;
  v_filas_por_rut jsonb;
  v_filas_por_correo jsonb;
  v_repetidas text;
  v_creadas int := 0;
  v_actualizadas int := 0;
  v_rechazadas int := 0;
  v_correo_re constant text := '^[^@\s]+@[^@\s]+\.[^@\s]+$';
BEGIN
  PERFORM public.exigir_directiva('carga fichas de voluntariado');
  IF NOT EXISTS (SELECT 1 FROM public.sedes WHERE id = p_sede_id) THEN
    RAISE EXCEPTION 'Elige la sede de destino.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p_filas) IS DISTINCT FROM 'array' OR jsonb_array_length(p_filas) = 0 THEN
    RAISE EXCEPTION 'La planilla no tiene filas.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_filas) > 1000 THEN
    RAISE EXCEPTION 'La planilla tiene más de 1.000 filas: divídela en varias cargas.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('importar_voluntarias'));

  -- Filas en que aparece cada RUT y cada correo
  SELECT coalesce(jsonb_object_agg(clave, filas), '{}'::jsonb) INTO v_filas_por_rut
  FROM (
    SELECT public.normalizar_rut(f->>'rut') AS clave,
           string_agg(coalesce(nullif(f->>'fila', ''), '0'), ', ' ORDER BY ord) AS filas
    FROM jsonb_array_elements(p_filas) WITH ORDINALITY AS t(f, ord)
    WHERE public.normalizar_rut(f->>'rut') <> ''
    GROUP BY 1
  ) r;
  SELECT coalesce(jsonb_object_agg(clave, filas), '{}'::jsonb) INTO v_filas_por_correo
  FROM (
    SELECT lower(btrim(f->>'correo')) AS clave,
           string_agg(coalesce(nullif(f->>'fila', ''), '0'), ', ' ORDER BY ord) AS filas
    FROM jsonb_array_elements(p_filas) WITH ORDINALITY AS t(f, ord)
    WHERE coalesce(btrim(f->>'correo'), '') <> ''
    GROUP BY 1
  ) c;

  FOR v_fila IN SELECT value FROM jsonb_array_elements(p_filas) LOOP
    v_num := coalesce(nullif(v_fila->>'fila', '')::int, 0);
    v_errores := '{}';
    v_motivo := NULL;
    v_rut := nullif(btrim(v_fila->>'rut'), '');
    v_nombres := nullif(btrim(regexp_replace(v_fila->>'nombres', '\s+', ' ', 'g')), '');
    v_apellidos := nullif(btrim(regexp_replace(v_fila->>'apellidos', '\s+', ' ', 'g')), '');
    v_correo := nullif(lower(btrim(v_fila->>'correo')), '');
    v_telefono := nullif(btrim(v_fila->>'telefono'), '');
    v_institucion := nullif(btrim(regexp_replace(v_fila->>'institucion', '\s+', ' ', 'g')), '');
    v_rol_txt := btrim(coalesce(v_fila->>'rol', ''));
    v_rol := public.rol_voluntariado(v_rol_txt);
    v_fecha_txt := nullif(btrim(v_fila->>'fecha_ingreso'), '');
    v_fecha := public.fecha_o_null(v_fecha_txt);
    v_ficha := NULL;
    v_perfil := NULL;

    IF v_rut IS NOT NULL AND public.rut_valido(v_rut) THEN
      v_rut := public.formatear_rut(v_rut);
      SELECT * INTO v_ficha FROM public.voluntarios_detalle
      WHERE public.normalizar_rut(rut) = public.normalizar_rut(v_rut);
      SELECT * INTO v_perfil FROM public.perfiles
      WHERE public.normalizar_rut(rut) = public.normalizar_rut(v_rut);
    END IF;

    -- Datos de la fila
    IF v_rut IS NULL THEN
      v_errores := array_append(v_errores, 'Falta el RUT');
    ELSIF NOT public.rut_valido(v_rut) THEN
      v_errores := array_append(v_errores, 'RUT inválido (dígito verificador)');
    ELSE
      v_repetidas := v_filas_por_rut ->> public.normalizar_rut(v_rut);
      IF v_repetidas LIKE '%,%' THEN
        v_errores := array_append(v_errores, format('RUT repetido en la planilla (filas %s)', v_repetidas));
      END IF;
    END IF;
    IF v_nombres IS NULL OR v_apellidos IS NULL THEN
      v_errores := array_append(v_errores, 'Faltan los nombres o apellidos');
    ELSIF length(v_nombres) > 100 OR length(v_apellidos) > 100 THEN
      v_errores := array_append(v_errores, 'Nombres o apellidos de más de 100 caracteres');
    END IF;
    IF v_correo IS NULL THEN
      v_errores := array_append(v_errores, 'Falta el correo');
    ELSIF v_correo !~ v_correo_re OR length(v_correo) > 150 THEN
      v_errores := array_append(v_errores, 'Correo con formato inválido');
    ELSIF v_correo NOT LIKE '%@ninaspro.cl' THEN
      v_errores := array_append(v_errores, 'El voluntariado usa su correo institucional @ninaspro.cl');
    ELSE
      v_repetidas := v_filas_por_correo ->> v_correo;
      IF v_repetidas LIKE '%,%' THEN
        v_errores := array_append(v_errores, format('Correo repetido en la planilla (filas %s)', v_repetidas));
      ELSIF EXISTS (
          SELECT 1 FROM public.voluntarios_detalle v
          WHERE v.correo = v_correo AND public.normalizar_rut(v.rut) <> public.normalizar_rut(coalesce(v_rut, ''))
        ) OR EXISTS (
          SELECT 1 FROM public.perfiles p
          WHERE lower(p.correo) = v_correo AND public.normalizar_rut(p.rut) <> public.normalizar_rut(coalesce(v_rut, ''))
        ) OR EXISTS (
          SELECT 1 FROM public.correos_autorizados ca
          WHERE ca.correo = v_correo AND ca.usado_en IS NULL AND ca.expira_en > timezone('utc'::text, now())
            AND public.normalizar_rut(coalesce(ca.rut, '')) <> public.normalizar_rut(coalesce(v_rut, ''))
        ) THEN
        v_errores := array_append(v_errores, 'El correo ya lo usa otra persona');
      END IF;
    END IF;
    IF v_telefono IS NOT NULL AND length(v_telefono) > 20 THEN
      v_errores := array_append(v_errores, 'Teléfono de más de 20 caracteres');
    END IF;
    IF v_institucion IS NOT NULL AND length(v_institucion) > 150 THEN
      v_errores := array_append(v_errores, 'Institución u ocupación de más de 150 caracteres');
    END IF;
    IF v_rol IS NULL THEN
      v_errores := array_append(v_errores, format('Rol desconocido "%s" (usa Tutora o Equipo de Gestión)', v_rol_txt));
    END IF;
    IF v_fecha_txt IS NOT NULL AND v_fecha IS NULL THEN
      v_errores := array_append(v_errores, 'Fecha de ingreso inválida');
    ELSIF v_fecha > public.hoy_chile() THEN
      v_errores := array_append(v_errores, 'La fecha de ingreso no puede ser futura');
    END IF;

    -- Coherencia con la ficha o la cuenta que ya tiene ese RUT
    IF v_ficha.id IS NOT NULL AND v_correo IS NOT NULL AND v_ficha.correo <> v_correo THEN
      v_errores := array_append(v_errores, format('Este RUT ya tiene ficha con el correo %s', v_ficha.correo));
    END IF;
    IF v_ficha.id IS NULL AND v_perfil.id IS NOT NULL THEN
      IF v_perfil.rol NOT IN ('tutora', 'equipo_gestion') THEN
        v_errores := array_append(v_errores, 'Este RUT corresponde a una cuenta que no es del voluntariado');
      ELSIF v_correo IS NOT NULL AND lower(v_perfil.correo) <> v_correo THEN
        v_errores := array_append(v_errores, format('Este RUT ya tiene cuenta con el correo %s', lower(v_perfil.correo)));
      END IF;
    END IF;

    IF cardinality(v_errores) > 0 THEN
      v_estado := 'invalida';
      v_motivo := array_to_string(v_errores, '; ');
      v_rechazadas := v_rechazadas + 1;
    ELSIF v_ficha.id IS NOT NULL THEN
      v_estado := 'existente';
      v_motivo := CASE WHEN v_ficha.fecha_salida IS NOT NULL
        THEN 'Ya tenía ficha y estaba retirada: se reincorpora'
        ELSE 'Ya tenía ficha: se conserva y se suma la sede' END;
      v_actualizadas := v_actualizadas + 1;
      IF NOT p_solo_validar THEN
        UPDATE public.voluntarios_detalle
        SET sede_id = p_sede_id,
            telefono = coalesce(v_telefono, telefono),
            institucion_u_ocupacion = coalesce(v_institucion, institucion_u_ocupacion),
            fecha_salida = NULL
        WHERE id = v_ficha.id
        RETURNING * INTO v_ficha;
        IF v_ficha.perfil_id IS NOT NULL THEN
          UPDATE public.perfiles SET activo = true, updated_at = timezone('utc'::text, now())
          WHERE id = v_ficha.perfil_id AND NOT activo;
          INSERT INTO public.usuarios_sedes (perfil_id, sede_id) VALUES (v_ficha.perfil_id, p_sede_id)
          ON CONFLICT (perfil_id, sede_id) DO NOTHING;
        ELSE
          UPDATE public.correos_autorizados SET sede_id = p_sede_id
          WHERE correo = v_ficha.correo AND usado_en IS NULL;
          PERFORM public.autorizar_correo_voluntaria(v_ficha);
        END IF;
      END IF;
    ELSE
      v_estado := 'nueva';
      v_motivo := CASE WHEN v_perfil.id IS NOT NULL THEN 'Ya tenía cuenta: se crea su ficha' END;
      v_creadas := v_creadas + 1;
      IF NOT p_solo_validar THEN
        INSERT INTO public.voluntarios_detalle (
          perfil_id, rut, nombres, apellidos, correo, telefono, institucion_u_ocupacion, rol, sede_id, fecha_ingreso
        ) VALUES (
          v_perfil.id,
          v_rut,
          coalesce(v_perfil.nombres, v_nombres),
          coalesce(v_perfil.apellidos, v_apellidos),
          v_correo,
          v_telefono,
          v_institucion,
          coalesce(v_perfil.rol, v_rol),
          p_sede_id,
          coalesce(v_fecha, public.hoy_chile())
        )
        RETURNING * INTO v_ficha;
        IF v_perfil.id IS NOT NULL THEN
          INSERT INTO public.usuarios_sedes (perfil_id, sede_id) VALUES (v_perfil.id, p_sede_id)
          ON CONFLICT (perfil_id, sede_id) DO NOTHING;
        ELSE
          PERFORM public.autorizar_correo_voluntaria(v_ficha);
        END IF;
      END IF;
    END IF;

    v_resultado := v_resultado || jsonb_build_object(
      'fila', v_num,
      'rut', coalesce(v_rut, ''),
      'nombre', btrim(coalesce(v_nombres, '') || ' ' || coalesce(v_apellidos, '')),
      'correo', coalesce(v_correo, ''),
      'rol', v_rol,
      'estado', v_estado,
      'motivo', v_motivo,
      'ficha_id', CASE WHEN NOT p_solo_validar AND v_estado <> 'invalida' THEN v_ficha.id END
    );
  END LOOP;

  RETURN jsonb_build_object(
    'filas', v_resultado,
    'creadas', v_creadas,
    'actualizadas', v_actualizadas,
    'rechazadas', v_rechazadas
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. ADHESIÓN, ROL, SALIDA Y AUTORIZACIÓN (US-31, US-32)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_adhesion_voluntaria(p_id uuid, p_firmada boolean, p_fecha date DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  PERFORM public.exigir_directiva('registra la declaración de adhesión');
  v_ficha := public.ficha_voluntaria(p_id);
  IF v_ficha.fecha_salida IS NOT NULL THEN
    RAISE EXCEPTION 'La voluntaria está retirada: reincorpórala antes de cambiar su adhesión.' USING ERRCODE = '22023';
  END IF;
  IF p_firmada AND p_fecha IS NULL THEN
    RAISE EXCEPTION 'Indica la fecha en que firmó la declaración.' USING ERRCODE = '22023';
  END IF;
  IF p_firmada AND p_fecha > public.hoy_chile() THEN
    RAISE EXCEPTION 'La fecha de firma no puede ser futura.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.voluntarios_detalle
  SET declaracion_adhesion_firmada = coalesce(p_firmada, false),
      fecha_firma_declaracion = CASE WHEN p_firmada THEN p_fecha::timestamptz END
  WHERE id = p_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cambiar_rol_voluntaria(p_id uuid, p_rol public.rol_usuario)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  PERFORM public.exigir_directiva('cambia el rol del voluntariado');
  v_ficha := public.ficha_voluntaria(p_id);
  IF p_rol NOT IN ('tutora', 'equipo_gestion') THEN
    RAISE EXCEPTION 'El voluntariado es Tutora o Equipo de Gestión.' USING ERRCODE = '22023';
  END IF;
  IF v_ficha.fecha_salida IS NOT NULL THEN
    RAISE EXCEPTION 'La voluntaria está retirada: reincorpórala antes de cambiar su rol.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.voluntarios_detalle SET rol = p_rol WHERE id = p_id;
  IF v_ficha.perfil_id IS NOT NULL THEN
    UPDATE public.perfiles SET rol = p_rol, updated_at = timezone('utc'::text, now())
    WHERE id = v_ficha.perfil_id AND rol IS DISTINCT FROM p_rol;
    IF p_rol = 'tutora' THEN
      UPDATE public.usuarios_sedes SET es_lider_sede = false WHERE perfil_id = v_ficha.perfil_id AND es_lider_sede;
    END IF;
  END IF;
  UPDATE public.correos_autorizados
  SET rol = p_rol, es_lider_sede = es_lider_sede AND p_rol = 'equipo_gestion'
  WHERE correo = v_ficha.correo AND usado_en IS NULL;
END;
$$;

-- La salida desactiva la cuenta, anula su autorización pendiente y quita sus
-- roles de las clases posteriores. La ficha y sus cursos se conservan (RB-10).
CREATE OR REPLACE FUNCTION public.registrar_salida_voluntaria(p_id uuid, p_fecha date)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  PERFORM public.exigir_directiva('registra la salida del voluntariado');
  v_ficha := public.ficha_voluntaria(p_id);
  IF v_ficha.fecha_salida IS NOT NULL THEN
    RAISE EXCEPTION 'La voluntaria ya tiene registrada su salida.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha IS NULL THEN
    RAISE EXCEPTION 'Indica la fecha de salida.' USING ERRCODE = '22023';
  END IF;
  IF p_fecha < v_ficha.fecha_ingreso THEN
    RAISE EXCEPTION 'La fecha de salida no puede ser anterior al ingreso (%).', to_char(v_ficha.fecha_ingreso, 'DD/MM/YYYY')
      USING ERRCODE = '22023';
  END IF;
  IF p_fecha > public.hoy_chile() THEN
    RAISE EXCEPTION 'La fecha de salida no puede ser futura: regístrala el día que se retira.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.voluntarios_detalle SET fecha_salida = p_fecha WHERE id = p_id;
  DELETE FROM public.correos_autorizados WHERE correo = v_ficha.correo AND usado_en IS NULL;
  IF v_ficha.perfil_id IS NOT NULL THEN
    UPDATE public.perfiles SET activo = false, updated_at = timezone('utc'::text, now()) WHERE id = v_ficha.perfil_id;
    DELETE FROM public.tareas_semanales_tutores t
    USING public.clases c
    WHERE c.id = t.clase_id AND t.tutor_id = v_ficha.perfil_id AND c.fecha > p_fecha;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.reincorporar_voluntaria(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  PERFORM public.exigir_directiva('reincorpora al voluntariado');
  v_ficha := public.ficha_voluntaria(p_id);
  IF v_ficha.fecha_salida IS NULL THEN
    RAISE EXCEPTION 'La voluntaria no está retirada.' USING ERRCODE = '22023';
  END IF;

  UPDATE public.voluntarios_detalle SET fecha_salida = NULL WHERE id = p_id RETURNING * INTO v_ficha;
  IF v_ficha.perfil_id IS NOT NULL THEN
    UPDATE public.perfiles SET activo = true, updated_at = timezone('utc'::text, now()) WHERE id = v_ficha.perfil_id;
  ELSE
    PERFORM public.autorizar_correo_voluntaria(v_ficha);
  END IF;
END;
$$;

-- La autorización del correo vence a los 30 días: la Directiva la renueva
CREATE OR REPLACE FUNCTION public.renovar_autorizacion_voluntaria(p_id uuid)
RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  PERFORM public.exigir_directiva('autoriza correos del voluntariado');
  v_ficha := public.ficha_voluntaria(p_id);
  IF v_ficha.perfil_id IS NOT NULL THEN
    RAISE EXCEPTION 'La voluntaria ya tiene su cuenta.' USING ERRCODE = '22023';
  END IF;
  IF v_ficha.fecha_salida IS NOT NULL THEN
    RAISE EXCEPTION 'La voluntaria está retirada: reincorpórala para autorizar su correo.' USING ERRCODE = '22023';
  END IF;
  IF v_ficha.sede_id IS NULL THEN
    RAISE EXCEPTION 'La ficha no tiene sede.' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.correos_autorizados WHERE correo = v_ficha.correo AND usado_en IS NULL;
  RETURN public.autorizar_correo_voluntaria(v_ficha);
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. ASIGNACIÓN A CURSOS (US-31 escenario 3): solo la Directiva
-- -----------------------------------------------------------------------------
-- El trigger tutores_instancia_adhesion (migración 15) exige la adhesión
-- firmada y que siga en el voluntariado. Al asignarla a un curso de otra sede,
-- la sede se suma a su cuenta para que vea esa clase (US-30 escenario 2).
CREATE OR REPLACE FUNCTION public.asignar_voluntaria_curso(p_id uuid, p_instancia_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
  v_instancia public.instancias_curso;
BEGIN
  PERFORM public.exigir_directiva('asigna tutoras a los cursos');
  v_ficha := public.ficha_voluntaria(p_id);
  SELECT * INTO v_instancia FROM public.instancias_curso WHERE id = p_instancia_id;
  IF v_instancia.id IS NULL THEN
    RAISE EXCEPTION 'El curso no existe.' USING ERRCODE = '22023';
  END IF;
  IF v_ficha.fecha_salida IS NOT NULL THEN
    RAISE EXCEPTION 'La voluntaria ya no participa del voluntariado: no se asigna a cursos.' USING ERRCODE = '22023';
  END IF;
  IF NOT v_ficha.declaracion_adhesion_firmada THEN
    RAISE EXCEPTION 'Para asignarla a un curso, la voluntaria debe tener firmada la declaración de adhesión.'
      USING ERRCODE = '22023';
  END IF;
  IF v_ficha.perfil_id IS NULL THEN
    RAISE EXCEPTION 'Aún no crea su cuenta con %: podrás asignarla cuando entre por primera vez.', v_ficha.correo
      USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.tutores_instancia WHERE instancia_curso_id = p_instancia_id AND tutor_id = v_ficha.perfil_id
  ) THEN
    RAISE EXCEPTION 'Ya está asignada a este curso.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.tutores_instancia (instancia_curso_id, tutor_id, asignado_por)
  VALUES (p_instancia_id, v_ficha.perfil_id, auth.uid());
  INSERT INTO public.usuarios_sedes (perfil_id, sede_id) VALUES (v_ficha.perfil_id, v_instancia.sede_id)
  ON CONFLICT (perfil_id, sede_id) DO NOTHING;
END;
$$;

-- Deshacer una asignación hecha por error: solo si aún no registra clases en ese curso
CREATE OR REPLACE FUNCTION public.quitar_voluntaria_curso(p_id uuid, p_instancia_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_ficha public.voluntarios_detalle;
BEGIN
  PERFORM public.exigir_directiva('asigna tutoras a los cursos');
  v_ficha := public.ficha_voluntaria(p_id);
  IF v_ficha.perfil_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.tutores_instancia WHERE instancia_curso_id = p_instancia_id AND tutor_id = v_ficha.perfil_id
  ) THEN
    RAISE EXCEPTION 'No está asignada a este curso.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.asistencia_tutores at JOIN public.clases c ON c.id = at.clase_id
    WHERE c.instancia_curso_id = p_instancia_id AND at.tutor_id = v_ficha.perfil_id
  ) OR EXISTS (
    SELECT 1 FROM public.tareas_semanales_tutores t JOIN public.clases c ON c.id = t.clase_id
    WHERE c.instancia_curso_id = p_instancia_id AND t.tutor_id = v_ficha.perfil_id
  ) THEN
    RAISE EXCEPTION 'Ya tiene clases o roles registrados en este curso: queda en su trayectoria.' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.tutores_instancia WHERE instancia_curso_id = p_instancia_id AND tutor_id = v_ficha.perfil_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 8. DIRECTORIO DEL VOLUNTARIADO (US-32)
-- -----------------------------------------------------------------------------
CREATE VIEW public.voluntariado WITH (security_invoker = true) AS
SELECT
  v.id,
  v.perfil_id,
  v.rut,
  v.nombres,
  v.apellidos,
  v.correo,
  v.telefono,
  v.institucion_u_ocupacion AS institucion,
  v.rol,
  v.sede_id,
  s.nombre AS sede_nombre,
  v.fecha_ingreso,
  v.fecha_salida,
  CASE WHEN v.fecha_salida IS NULL THEN 'activa' ELSE 'retirada' END AS estado,
  v.declaracion_adhesion_firmada AS adhesion_firmada,
  v.fecha_firma_declaracion::date AS fecha_firma_adhesion,
  CASE
    WHEN v.perfil_id IS NOT NULL THEN CASE WHEN p.activo THEN 'activa' ELSE 'inactiva' END
    WHEN ca.id IS NOT NULL THEN 'autorizada'
    ELSE 'sin_autorizacion'
  END AS cuenta,
  ca.expira_en AS autorizacion_expira_en,
  coalesce(cursos.lista, '[]'::jsonb) AS cursos,
  ARRAY(
    SELECT DISTINCT x FROM unnest(
      array_append(coalesce(cursos.sedes, '{}'::uuid[]), v.sede_id)
      || ARRAY(SELECT us.sede_id FROM public.usuarios_sedes us WHERE us.perfil_id = v.perfil_id)
    ) AS x WHERE x IS NOT NULL
  ) AS sede_ids,
  v.created_at
FROM public.voluntarios_detalle v
LEFT JOIN public.sedes s ON s.id = v.sede_id
LEFT JOIN public.perfiles p ON p.id = v.perfil_id
LEFT JOIN LATERAL (
  SELECT c.id, c.expira_en FROM public.correos_autorizados c
  WHERE v.perfil_id IS NULL AND c.correo = v.correo AND c.usado_en IS NULL
    AND c.expira_en > timezone('utc'::text, now())
  ORDER BY c.expira_en DESC LIMIT 1
) ca ON true
LEFT JOIN LATERAL (
  SELECT
    jsonb_agg(jsonb_build_object(
      'instancia_id', ic.id,
      'curso_codigo', cu.codigo,
      'curso_nombre', cu.nombre,
      'sede_id', ic.sede_id,
      'sede_nombre', se.nombre,
      'periodo', ic.periodo_academico,
      'seccion', ic.seccion,
      'fecha_inicio', ic.fecha_inicio
    ) ORDER BY ic.fecha_inicio, cu.codigo) AS lista,
    array_agg(DISTINCT ic.sede_id) AS sedes
  FROM public.tutores_instancia ti
  JOIN public.instancias_curso ic ON ic.id = ti.instancia_curso_id
  JOIN public.cursos cu ON cu.id = ic.curso_id
  JOIN public.sedes se ON se.id = ic.sede_id
  WHERE ti.tutor_id = v.perfil_id
) cursos ON true;

REVOKE ALL ON public.voluntariado FROM anon, public;
GRANT SELECT ON public.voluntariado TO authenticated;

-- -----------------------------------------------------------------------------
-- 9. CATÁLOGO DE ROLES (US-43 escenario 1): la Directiva
-- -----------------------------------------------------------------------------
-- Un nombre por rol aunque cambien tildes o mayúsculas. El código es interno:
-- si no viene, se genera.
CREATE UNIQUE INDEX rol_tarea_tutor_nombre_unico ON public.rol_tarea_tutor (public.clave_nombre(nombre));

CREATE OR REPLACE FUNCTION public.validar_rol_tarea_tutor()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  NEW.nombre := btrim(regexp_replace(coalesce(NEW.nombre, ''), '\s+', ' ', 'g'));
  NEW.descripcion := nullif(btrim(coalesce(NEW.descripcion, '')), '');
  IF NEW.nombre = '' THEN
    RAISE EXCEPTION 'Escribe el nombre del rol.' USING ERRCODE = '22023';
  END IF;
  IF length(NEW.descripcion) > 300 THEN
    RAISE EXCEPTION 'La descripción del rol tiene más de 300 caracteres.' USING ERRCODE = '22023';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.codigo := coalesce(nullif(btrim(NEW.codigo), ''), 'rol_' || left(replace(gen_random_uuid()::text, '-', ''), 12));
  ELSIF NEW.codigo IS DISTINCT FROM OLD.codigo THEN
    RAISE EXCEPTION 'El código del rol no se cambia.' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER rol_tarea_tutor_validar
  BEFORE INSERT OR UPDATE ON public.rol_tarea_tutor
  FOR EACH ROW EXECUTE FUNCTION public.validar_rol_tarea_tutor();

-- -----------------------------------------------------------------------------
-- 10. ROLES DE CADA CLASE (US-43 escenarios 2..4, US-44)
-- -----------------------------------------------------------------------------
-- Equipo del curso de la clase con sus roles. Lo ven Gestión y las tutoras de
-- la sede (US-44 escenario 3). Quien salió del voluntariado antes de la clase
-- solo aparece si tenía roles en ella.
CREATE OR REPLACE FUNCTION public.roles_clase(p_clase_id uuid)
RETURNS TABLE (
  tutor_id uuid,
  nombres text,
  apellidos text,
  es_equipo_gestion boolean,
  tareas jsonb
)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  WITH clase AS (
    SELECT c.id, c.instancia_curso_id, c.fecha FROM public.clases c WHERE c.id = p_clase_id
  ),
  personas AS (
    SELECT ti.tutor_id
    FROM clase JOIN public.tutores_instancia ti ON ti.instancia_curso_id = clase.instancia_curso_id
    LEFT JOIN public.voluntarios_detalle v ON v.perfil_id = ti.tutor_id
    WHERE v.fecha_salida IS NULL OR v.fecha_salida >= clase.fecha
    UNION
    SELECT t.tutor_id FROM public.tareas_semanales_tutores t WHERE t.clase_id = p_clase_id
  )
  SELECT
    p.id,
    p.nombres::text,
    p.apellidos::text,
    p.rol = 'equipo_gestion',
    coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id,
        'rol_id', t.rol_tarea_tutor_id,
        'completada', t.completada
      ) ORDER BY r.es_requerido DESC, r.nombre)
      FROM public.tareas_semanales_tutores t
      JOIN public.rol_tarea_tutor r ON r.id = t.rol_tarea_tutor_id
      WHERE t.clase_id = p_clase_id AND t.tutor_id = p.id
    ), '[]'::jsonb)
  FROM personas x
  JOIN public.perfiles p ON p.id = x.tutor_id
  WHERE public.es_staff_sede(public.sede_clase(p_clase_id))
  ORDER BY p.nombres, p.apellidos;
$$;

-- Roles de la tutora autenticada en cada clase de un curso (su historial y la clase de hoy)
CREATE OR REPLACE FUNCTION public.mis_roles_curso(p_instancia_id uuid)
RETURNS TABLE (
  tarea_id uuid,
  clase_id uuid,
  numero_sesion int,
  rol_id uuid,
  completada boolean
)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT t.id, c.id, c.numero_sesion, t.rol_tarea_tutor_id, t.completada
  FROM public.tareas_semanales_tutores t
  JOIN public.clases c ON c.id = t.clase_id
  WHERE c.instancia_curso_id = p_instancia_id AND t.tutor_id = auth.uid()
  ORDER BY c.numero_sesion;
$$;

-- Gestión de la sede deja los roles de una tutora en una clase: los que no
-- vienen se quitan y los nuevos quedan pendientes (los que siguen conservan
-- su cumplimiento). Una lista vacía la deja sin roles.
CREATE OR REPLACE FUNCTION public.guardar_roles_tutora(p_clase_id uuid, p_tutor_id uuid, p_roles uuid[])
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_clase public.clases;
  v_roles uuid[] := ARRAY(SELECT DISTINCT x FROM unnest(coalesce(p_roles, '{}'::uuid[])) AS x WHERE x IS NOT NULL);
  v_salida date;
BEGIN
  SELECT * INTO v_clase FROM public.clases WHERE id = p_clase_id;
  IF v_clase.id IS NULL THEN
    RAISE EXCEPTION 'La clase no existe.' USING ERRCODE = '22023';
  END IF;
  IF NOT public.gestiona_sede(public.sede_clase(p_clase_id)) THEN
    RAISE EXCEPTION 'Solo el Equipo de Gestión de la sede asigna los roles de la clase.' USING ERRCODE = '42501';
  END IF;
  IF v_clase.estado = 'suspendida' THEN
    RAISE EXCEPTION 'La clase está suspendida: no se asignan roles.' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.tutores_instancia
    WHERE instancia_curso_id = v_clase.instancia_curso_id AND tutor_id = p_tutor_id
  ) THEN
    RAISE EXCEPTION 'La tutora no está asignada al curso de esta clase.' USING ERRCODE = '22023';
  END IF;
  SELECT fecha_salida INTO v_salida FROM public.voluntarios_detalle WHERE perfil_id = p_tutor_id;
  IF v_salida IS NOT NULL AND v_salida < v_clase.fecha AND cardinality(v_roles) > 0 THEN
    RAISE EXCEPTION 'La tutora ya no participa del voluntariado en esta fecha.' USING ERRCODE = '22023';
  END IF;
  -- Los roles nuevos deben estar activos en el catálogo
  IF EXISTS (
    SELECT 1 FROM unnest(v_roles) AS x
    LEFT JOIN public.rol_tarea_tutor r ON r.id = x
    WHERE (r.id IS NULL OR NOT r.activo)
      AND NOT EXISTS (
        SELECT 1 FROM public.tareas_semanales_tutores t
        WHERE t.clase_id = p_clase_id AND t.tutor_id = p_tutor_id AND t.rol_tarea_tutor_id = x
      )
  ) THEN
    RAISE EXCEPTION 'Uno de los roles no existe o ya no está activo en el catálogo.' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('roles_clase' || p_clase_id::text || p_tutor_id::text));

  DELETE FROM public.tareas_semanales_tutores
  WHERE clase_id = p_clase_id AND tutor_id = p_tutor_id AND NOT (rol_tarea_tutor_id = ANY (v_roles));

  INSERT INTO public.tareas_semanales_tutores (clase_id, tutor_id, rol_tarea_tutor_id)
  SELECT p_clase_id, p_tutor_id, x FROM unnest(v_roles) AS x
  ON CONFLICT (clase_id, tutor_id, rol_tarea_tutor_id) DO NOTHING;
END;
$$;

-- La tutora marca el cumplimiento de sus roles; Gestión de la sede, el de cualquiera (US-44)
CREATE OR REPLACE FUNCTION public.marcar_rol_cumplido(p_tarea_id uuid, p_completada boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_tarea public.tareas_semanales_tutores;
BEGIN
  SELECT * INTO v_tarea FROM public.tareas_semanales_tutores WHERE id = p_tarea_id;
  IF v_tarea.id IS NULL THEN
    RAISE EXCEPTION 'El rol ya no está asignado.' USING ERRCODE = '22023';
  END IF;
  IF NOT (
    (v_tarea.tutor_id = auth.uid() AND public.current_user_role() IS NOT NULL)
    OR public.gestiona_sede(public.sede_clase(v_tarea.clase_id))
  ) THEN
    RAISE EXCEPTION 'Solo la tutora o el Equipo de Gestión de la sede marcan este rol.' USING ERRCODE = '42501';
  END IF;

  UPDATE public.tareas_semanales_tutores SET completada = coalesce(p_completada, false) WHERE id = p_tarea_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 11. PASE DE LISTA DE TUTORAS SIN QUIENES YA SALIERON (US-33)
-- -----------------------------------------------------------------------------
-- Igual que en la migración 15, sin las voluntarias retiradas antes de la clase
-- (salvo que ya tengan su asistencia registrada en ella).
CREATE OR REPLACE FUNCTION public.lista_asistencia_tutores(p_clase_id uuid)
RETURNS TABLE (
  tutor_id uuid,
  nombres text,
  apellidos text,
  es_equipo_gestion boolean,
  estado public.estado_asistencia,
  registrado_por_nombre text,
  actualizado_en timestamptz
)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  WITH personas AS (
    SELECT ti.tutor_id
    FROM public.clases c
    JOIN public.tutores_instancia ti ON ti.instancia_curso_id = c.instancia_curso_id
    LEFT JOIN public.voluntarios_detalle v ON v.perfil_id = ti.tutor_id
    WHERE c.id = p_clase_id AND (v.fecha_salida IS NULL OR v.fecha_salida >= c.fecha)
    UNION
    SELECT at.tutor_id FROM public.asistencia_tutores at WHERE at.clase_id = p_clase_id
  )
  SELECT
    p.id,
    p.nombres::text,
    p.apellidos::text,
    p.rol = 'equipo_gestion',
    at.estado,
    nullif(btrim(concat_ws(' ', r.nombres, r.apellidos)), ''),
    at.updated_at
  FROM personas x
  JOIN public.perfiles p ON p.id = x.tutor_id
  LEFT JOIN public.asistencia_tutores at ON at.clase_id = p_clase_id AND at.tutor_id = p.id
  LEFT JOIN public.perfiles r ON r.id = at.registrado_por
  ORDER BY p.nombres, p.apellidos;
$$;

-- -----------------------------------------------------------------------------
-- 12. AUDITORÍA (US-23)
-- -----------------------------------------------------------------------------
CREATE TRIGGER voluntarios_detalle_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.voluntarios_detalle
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER tutores_instancia_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.tutores_instancia
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER rol_tarea_tutor_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.rol_tarea_tutor
  FOR EACH ROW EXECUTE FUNCTION public.auditar();
CREATE TRIGGER tareas_semanales_tutores_auditar
  AFTER INSERT OR UPDATE OR DELETE ON public.tareas_semanales_tutores
  FOR EACH ROW EXECUTE FUNCTION public.auditar();

-- -----------------------------------------------------------------------------
-- 13. PERMISOS DE LAS FUNCIONES
-- -----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.completar_ficha_voluntaria() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validar_rol_tarea_tutor() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rol_voluntariado(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ficha_voluntaria(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.autorizar_correo_voluntaria(public.voluntarios_detalle) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.importar_voluntarias(uuid, jsonb, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_adhesion_voluntaria(uuid, boolean, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cambiar_rol_voluntaria(uuid, public.rol_usuario) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_salida_voluntaria(uuid, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reincorporar_voluntaria(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.renovar_autorizacion_voluntaria(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.asignar_voluntaria_curso(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.quitar_voluntaria_curso(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.roles_clase(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mis_roles_curso(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.guardar_roles_tutora(uuid, uuid, uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.marcar_rol_cumplido(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.lista_asistencia_tutores(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.importar_voluntarias(uuid, jsonb, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_adhesion_voluntaria(uuid, boolean, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cambiar_rol_voluntaria(uuid, public.rol_usuario) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_salida_voluntaria(uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reincorporar_voluntaria(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.renovar_autorizacion_voluntaria(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.asignar_voluntaria_curso(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.quitar_voluntaria_curso(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.roles_clase(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mis_roles_curso(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_roles_tutora(uuid, uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.marcar_rol_cumplido(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lista_asistencia_tutores(uuid) TO authenticated;
