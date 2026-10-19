---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-18: Subida Móvil de Evidencia Fotográfica con Compresión en Cliente"
labels: ["user-story", "Must", "RF-09", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-9 · Registro de evidencia fotográfica
- **Requisitos no funcionales (Indirectos):** RNF-R-1 (Tiempo de respuesta ≤ 1.5s), RNF-R-3 (Límite 1 GB anual), RNF-U-2 (≤ 3 min sin ayuda), RNF-C-1 (Navegadores móviles Safari/Chrome)
- **Reglas de negocio asociadas:** RB-10 (Conservación de imágenes por 2 años)

---

### 👤 Historia de Usuario
> **Como** tutora en la sala de clases,  
> **quiero** tomar una fotografía con la cámara de mi celular o seleccionarla desde la galería y subirla directamente a la sesión con compresión automática en el navegador,  
> **para** respaldar de forma ágil la realización de la clase sin agotar el plan de almacenamiento gratuito de la corporación.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Captura o selección directa desde celular):** Dada una clase realizada, cuando la tutora presiona "Agregar Foto de Evidencia" desde el navegador de su teléfono, entonces el sistema activa la cámara nativa del dispositivo o abre la galería de imágenes sin requerir apps externas.
- [ ] **Escenario 2 (Compresión client-side previa a la subida):** Dada una imagen de alta resolución (ej. 8 a 12 MB capturada por la cámara), cuando el navegador procesa el archivo antes de transmitirlo, entonces lo comprime a una resolución adecuada con un peso final inferior a 1,5 MB.
- [ ] **Escenario 3 (Asociación a la clase con autoría):** Dado el envío exitoso de la foto, cuando se completa la carga en el almacenamiento seguro, entonces la evidencia queda vinculada a la sesión registrando fecha, hora, tamaño en bytes y tutora autora.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Botón de captura/selección con selector `<input type="file" accept="image/*" capture="environment">`.
- [ ] Frontend / Lógica: Módulo de compresión de imágenes en el cliente (canvas o librería JS liviana) antes de invocar la subida.
- [ ] Backend / Lógica: Bucket de evidencias en Supabase Storage e inserción de registro en `evidencias_fotograficas`.
- [ ] Pruebas mínimas: TC-12 (Prueba de subida de imagen de 5 MB verificando peso comprimido < 1.5 MB y asociación correcta a la clase).
