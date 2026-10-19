---
name: "Historia de Usuario"
about: "Plantilla ágil y directa para historias de usuario con trazabilidad a RF/RNF"
title: "US-14: Almacenamiento Local Offline y Sincronización Automática de Asistencia"
labels: ["user-story", "Must", "RF-05", "Tutora"]
assignees: ""
---

### 📌 Trazabilidad
- **Prioridad / Tipo:** Must (MVP)
- **Requisito funcional (Base):** RF-5 · Registro de asistencia de alumnas por clase
- **Requisitos no funcionales (Indirectos):** RNF-D-2 (Continuidad de ventana de clases), RNF-C-1 (Compatibilidad Safari y Chrome móvil)
- **Reglas de negocio asociadas:** RB-7 (Trazabilidad)

---

### 👤 Historia de Usuario
> **Como** tutora en la sala de clases con conexión wifi inestable,  
> **quiero** que al guardar la asistencia sin conexión a internet los datos queden retenidos en mi navegador y se envíen automáticamente al reconectarse,  
> **para** no perder la información registrada ni tener que volver a pasar lista manualmente.

---

### ✅ Criterios de Aceptación
> *Condiciones necesarias para validar que la historia está lista.*
- [ ] **Escenario 1 (Guardado sin conexión con notificación):** Dado que la tutora finaliza el pase de lista pero se corta la conexión a internet en la sede, cuando presiona "Guardar Lista", entonces el sistema almacena la carga en el almacenamiento local del navegador (IndexedDB/LocalStorage) y muestra un indicador visual claro: "Pendiente de envío por falta de conexión".
- [ ] **Escenario 2 (Sincronización automática al recuperar señal):** Dado el registro retenido localmente, cuando el dispositivo móvil recupera la conexión a internet, entonces el sistema detecta la red y envía automáticamente la lista al backend sin requerir intervención de la tutora.
- [ ] **Escenario 3 (Confirmación y consistencia en navegadores móviles):** Dado un dispositivo Android (Chrome) o iPhone (Safari), cuando se produce la sincronización en segundo plano, entonces la interfaz actualiza el estado a "Guardado exitosamente" sin duplicar registros en la base de datos.

---

### 🛠️ Tareas
- [ ] Frontend / UI: Indicador de conectividad (Online/Offline) y alerta no intrusiva de sincronización pendiente.
- [ ] Frontend / Lógica: Mecanismo de persistencia local en cliente con cola de reintentos (`window.addEventListener('online')`).
- [ ] Pruebas mínimas: TC-08 (Prueba de corte de wifi simulado en Android y Safari/iPhone verificando sincronización íntegra sin duplicados).
