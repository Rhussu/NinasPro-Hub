-- =============================================================================
-- Migration: 20261101000012_catalogo_nombres_eliminacion.sql
-- Proyecto: Plataforma de Gestión Académica y Rendición - NiñasPro Hub
-- Descripción: Unicidad del catálogo sin distinguir tildes y eliminación de
--              sedes y cursos que aún no se usan (US-01).
--
--   - "Sede Valparaíso", "sede valparaiso" y "Sede  Valparaiso." son la misma
--     sede: la clave compara sin mayúsculas, tildes, espacios ni signos.
--   - Una sede o un curso se puede eliminar mientras no tenga instancias,
--     personas asignadas ni accesos pendientes. Si los tiene, la base lo
--     impide con un mensaje que dice qué lo está usando.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CLAVE DE COMPARACIÓN DE NOMBRES
-- -----------------------------------------------------------------------------
-- 'Sede San Joaquín' -> 'sedesanjoaquin'. Es la misma regla que usa la app
-- (claveNombre en lib/utils/nombres.dart) para avisar antes de guardar.
CREATE OR REPLACE FUNCTION public.clave_nombre(p_texto text)
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = ''
AS $$
  SELECT regexp_replace(
    translate(lower(p_texto), 'áàäâãéèëêíìïîóòöôõúùüûñç', 'aaaaaeeeeiiiiooooouuuunc'),
    '[^a-z0-9]+', '', 'g'
  );
$$;

-- -----------------------------------------------------------------------------
-- 2. SEDES Y CURSOS ÚNICOS SIN DISTINGUIR TILDES
-- -----------------------------------------------------------------------------
-- Si ya hay nombres que chocan con la regla nueva, los más recientes se
-- renombran con un sufijo en vez de borrarse: así la migración no pierde datos
-- y la Directiva puede eliminarlos o corregirlos desde la app.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT id, nombre, row_number() OVER (PARTITION BY public.clave_nombre(nombre) ORDER BY created_at, id) AS n
    FROM public.sedes
  LOOP
    IF r.n > 1 THEN
      UPDATE public.sedes SET nombre = left(r.nombre, 70) || ' (repetida ' || r.n || ')' WHERE id = r.id;
      RAISE NOTICE 'Sede "%" renombrada: su nombre coincidía con otra sin contar tildes', r.nombre;
    END IF;
  END LOOP;

  FOR r IN
    SELECT id, codigo, row_number() OVER (PARTITION BY public.clave_nombre(codigo) ORDER BY created_at, id) AS n
    FROM public.cursos
  LOOP
    IF r.n > 1 THEN
      UPDATE public.cursos SET codigo = left(r.codigo, 16) || '-R' || r.n WHERE id = r.id;
      RAISE NOTICE 'Curso "%" recodificado: su código coincidía con otro sin contar tildes ni signos', r.codigo;
    END IF;
  END LOOP;
END;
$$;

DROP INDEX public.sedes_nombre_unico;
CREATE UNIQUE INDEX sedes_nombre_clave_unica ON public.sedes (public.clave_nombre(nombre));
CREATE UNIQUE INDEX cursos_codigo_clave_unica ON public.cursos (public.clave_nombre(codigo));

ALTER TABLE public.sedes
  ADD CONSTRAINT sedes_nombre_con_letras CHECK (public.clave_nombre(nombre) <> '');
ALTER TABLE public.cursos
  ADD CONSTRAINT cursos_codigo_con_letras CHECK (public.clave_nombre(codigo) <> '');

-- -----------------------------------------------------------------------------
-- 3. ELIMINAR SOLO LO QUE NO SE USA
-- -----------------------------------------------------------------------------
-- '1 instancia de curso', '3 personas asignadas'
CREATE OR REPLACE FUNCTION public.contar_uso(p_cantidad bigint, p_singular text, p_plural text)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT CASE WHEN p_cantidad > 0 THEN p_cantidad || ' ' || CASE WHEN p_cantidad = 1 THEN p_singular ELSE p_plural END END;
$$;

-- Las instancias y las personas asignadas ya lo impiden por FK (RESTRICT), pero
-- los accesos pendientes se borrarían en cascada sin aviso. El trigger revisa
-- todo y responde con un mensaje que la app muestra tal cual.
CREATE OR REPLACE FUNCTION public.impedir_eliminar_sede_en_uso()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_usos text;
BEGIN
  SELECT concat_ws(', ',
    public.contar_uso((SELECT count(*) FROM public.instancias_curso WHERE sede_id = OLD.id), 'instancia de curso', 'instancias de curso'),
    public.contar_uso((SELECT count(*) FROM public.usuarios_sedes WHERE sede_id = OLD.id), 'persona asignada', 'personas asignadas'),
    public.contar_uso(
      (SELECT count(*) FROM public.correos_autorizados WHERE sede_id = OLD.id AND usado_en IS NULL),
      'acceso pendiente', 'accesos pendientes'
    )
  ) INTO v_usos;

  IF v_usos <> '' THEN
    RAISE EXCEPTION 'No se puede eliminar "%": tiene %. Puedes desactivarla en su lugar.', OLD.nombre, v_usos
      USING ERRCODE = '23503';
  END IF;
  RETURN OLD;
END;
$$;

CREATE TRIGGER sedes_impedir_eliminar_en_uso
  BEFORE DELETE ON public.sedes
  FOR EACH ROW EXECUTE FUNCTION public.impedir_eliminar_sede_en_uso();

CREATE OR REPLACE FUNCTION public.impedir_eliminar_curso_en_uso()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_instancias bigint;
BEGIN
  SELECT count(*) INTO v_instancias FROM public.instancias_curso WHERE curso_id = OLD.id;
  IF v_instancias > 0 THEN
    RAISE EXCEPTION 'No se puede eliminar "%": tiene %.', OLD.codigo,
      public.contar_uso(v_instancias, 'instancia de curso', 'instancias de curso')
      USING ERRCODE = '23503';
  END IF;
  RETURN OLD;
END;
$$;

CREATE TRIGGER cursos_impedir_eliminar_en_uso
  BEFORE DELETE ON public.cursos
  FOR EACH ROW EXECUTE FUNCTION public.impedir_eliminar_curso_en_uso();
