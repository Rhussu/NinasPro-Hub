# Lista legal · TC-34 (RNF-S-5, SRS §5.3 y §10.4)

Cotejo de la lista de verificación del SRS contra las pruebas que la respaldan.
- ✅ = cubierto por una prueba automatizada que pasa.
- ⬜ = requiere revisión manual.

| Requisito (SRS) | Cómo se verifica | Prueba | Estado |
|---|---|---|---|
| Consentimiento previo del apoderado (RF-4, RB-1) | La inscripción no pasa a activa sin la autorización de datos | pgTAP `09_alumnas_autorizaciones` · `alumnas_screens_test` («otorgar el consentimiento exige el respaldo y activa la matrícula») | ✅ |
| Imagen solo con autorización (RB-2, RB-3) | Un canal sin respuesta cuenta como no autorizado; la foto no queda apta sin autorización | pgTAP `14_justificativos_evidencias` · `justificativos_evidencias_test` | ✅ |
| Revocación con fecha (RB-4) | La revocación queda registrada y la foto deja de ser apta | `alumnas_screens_test` («revoca un canal con fecha y motivo») · pgTAP 09 | ✅ |
| Solo datos agregados a patrocinantes (RB-9) | La exportación disociada no lleva nombre ni RUT | `directorio_screens_test` («exportar descarga el archivo disociado…») · pgTAP 16 | ✅ |
| Minimización: sin diagnósticos (RB-8) | El justificativo no tiene un campo de diagnóstico y la explicación es breve | pgTAP 14 («El justificativo no tiene campo de diagnóstico (RB-8)») | ✅ |
| Derecho de acceso (RF-12 A1) | La auditoría filtrada por alumna muestra quién accedió a sus datos | pgTAP `12_auditoria` · `directorio_screens_test` (auditoría por RUT) | ✅ |
| Seguridad: TLS 1.2+ y AES-256 | Inspección del certificado y de la configuración del proveedor | `pruebas-rnf/seguridad/tls.sh` + `evidencias/` | ⬜ falta AES-256 |
| Datos sintéticos fuera de producción | Revisión del seed y de los ambientes | `supabase/seed.sql` es sintético (RUT válidos inventados, correos `@ninaspro.cl` y `@correo.cl` de demostración). La beta usa solo ese seed | ⬜ falta firmar |
| Mínimo privilegio por rol y sede (RB-6) | Sin acceso cruzado | `pruebas-rnf/seguridad/acceso_cruzado.js` (19/19) · pgTAP 04 y 18 | ✅ |
| Plazos de conservación (RB-10, RB-13) | La eliminación queda registrada | pgTAP 08 y 12 | ⬜ revisar plazos con la Directiva |

**Revisó:** ____________________ (Product Owner) · **Fecha:** ____________
