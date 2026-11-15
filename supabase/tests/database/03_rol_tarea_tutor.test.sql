BEGIN;
SELECT plan(7);

-- 1. El catálogo dinámico reemplaza al enum
SELECT has_table('public', 'rol_tarea_tutor', 'Tabla rol_tarea_tutor existe');
SELECT hasnt_column('public', 'tareas_semanales_tutores', 'tarea', 'La columna enum tarea fue eliminada');
SELECT col_not_null('public', 'tareas_semanales_tutores', 'rol_tarea_tutor_id', 'rol_tarea_tutor_id es obligatorio');
SELECT fk_ok(
  'public', 'tareas_semanales_tutores', 'rol_tarea_tutor_id',
  'public', 'rol_tarea_tutor', 'id',
  'tareas_semanales_tutores referencia al catálogo de roles'
);

-- 2. Los valores del enum anterior quedan cargados en el catálogo
SELECT set_has(
  $$ SELECT codigo::text FROM public.rol_tarea_tutor $$,
  $$ VALUES ('tutora_lider'), ('tutora_apoyo'), ('registro_asistencia'), ('dinamica_kahoot') $$,
  'El catálogo contiene los roles del enum anterior'
);

-- 3. El código del rol es único
SELECT throws_ok(
  $$ INSERT INTO public.rol_tarea_tutor (codigo, nombre) VALUES ('tutora_lider', 'Duplicado') $$,
  '23505',
  NULL,
  'Rechaza duplicar el código de un rol'
);

-- 4. Umbral de asistencia mínima por defecto
SELECT col_default_is(
  'public', 'instancias_curso', 'porcentaje_asistencia_minimo', '80',
  'El umbral de asistencia mínima por defecto es 80%'
);

SELECT * FROM finish();
ROLLBACK;
