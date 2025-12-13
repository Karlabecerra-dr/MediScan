# MediScan

MediScan es una aplicación móvil desarrollada en **Flutter** que permite a los usuarios gestionar y recordar la toma de medicamentos mediante notificaciones automáticas, una agenda diaria y un registro personalizado por usuario.

La aplicación está orientada a personas con tratamientos médicos continuos, especialmente adultos mayores o pacientes que requieren organización y recordatorios constantes para cumplir correctamente con sus indicaciones médicas.

---

## Objetivo del proyecto

Desarrollar una aplicación móvil funcional que permita:

- Registrar medicamentos de forma manual o mediante escaneo.
- Configurar días y horarios de toma.
- Generar notificaciones automáticas.
- Gestionar medicamentos de forma segura por usuario.

---

## Funcionalidades principales

### Autenticación de usuarios
- Registro e inicio de sesión con correo electrónico y contraseña.
- Gestión de cuenta (nombre, correo y cambio de contraseña).
- Recuperación de contraseña mediante correo electrónico.

### Gestión de medicamentos
- Agregar, editar y eliminar medicamentos.
- Definir días de la semana y horarios de toma.
- Visualización diaria de tomas pendientes y realizadas.

### Notificaciones
- Recordatorios automáticos según la configuración del usuario.
- Posposición de recordatorios.
- Sincronización de notificaciones al iniciar sesión.

### Escaneo de medicamentos
- Registro rápido mediante código de barras cuando la información está disponible.
- Autocompletado de datos básicos del medicamento.

---

## Arquitectura del proyecto

El proyecto sigue una estructura modular para separar responsabilidades y facilitar el mantenimiento:

lib/
├── models/ # Modelos de datos
├── screens/ # Pantallas principales (UI)
├── services/ # Lógica de negocio (Auth, Firestore, Notificaciones)
├── widgets/ # Componentes reutilizables

yaml
Copiar código

---

## Tecnologías utilizadas

- Flutter
- Firebase Authentication
- Cloud Firestore
- Flutter Local Notifications
- Mobile Scanner
- Material Design 3

---

## Seguridad

- Cada medicamento está asociado al `userId` del usuario autenticado.
- Los datos solo son accesibles por el propietario de la cuenta.
- La recuperación de contraseña se realiza mediante correo electrónico.
- Las notificaciones se sincronizan por usuario al iniciar sesión.

---

## Estado del proyecto

- Prototipo funcional.
- Flujo completo implementado.
- Cumple con los objetivos definidos en la planificación.

### Trabajo futuro
- Reportes de historial de tomas.
- Integración con cuidadores o profesionales de la salud.
- Exportación de datos médicos.

---

## Autores

- Karla Becerra  
- Susana Tapia