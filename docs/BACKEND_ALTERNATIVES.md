# 🏗️ Guía: Backend Propio (Django / Express)

Si decides migrar de Supabase (Backend-as-a-Service) a tu propio Backend personalizado, aquí tienes la hoja de ruta.

## Opción A: Express.js (Node.js)

Ideal si quieres mantener todo en JavaScript.

### Estructura
```
backend/
├── src/
│   ├── controllers/  # Lógica de negocio
│   ├── models/       # Modelos (Sequelize/TypeORM)
│   ├── routes/       # Endpoints API
│   └── middleware/   # Auth (JWT)
├── app.js
└── package.json
```

### Pasos de Migración
1. **API REST**: Crea endpoints que repliquen la funcionalidad de Supabase:
   - `POST /auth/login` -> Retorna JWT.
   - `GET /api/investments/me` -> Datos del usuario.
   - `POST /api/withdrawals` -> Crear retiro.
2. **Base de Datos**: Usa PostgreSQL directamente.
   - Instala `pg` y un ORM como `Prisma` o `Sequelize`.
3. **Autenticación**: Implementa `jsonwebtoken` y `bcrypt` para hashear contraseñas.
4. **Frontend**: Reemplaza `supabaseClient.js` por llamadas `axios` a tu nueva API.

## Opción B: Django (Python)

Ideal para seguridad robusta y panel de administración incluido.

### Estructura
- App `users`: CustomUser model.
- App `investments`: Modelos Investment y Withdrawal.

### Pasos
1. **Django Rest Framework (DRF)**: Úsalo para crear la API.
2. **Admin Panel**: Django trae un admin panel gratis que reemplaza tu vista `/admin` actual.
3. **JWT**: Usa `djangorestframework-simplejwt`.

## Despliegue en VPS (DigitalOcean / AWS)

1. **Servidor**: Compra un VPS (Ubuntu 22.04).
2. **Base de Datos**: Instala PostgreSQL (`sudo apt install postgresql`).
3. **Backend**:
   - Clona tu repo.
   - Instala dependencias (`npm install` o `pip install`).
   - Usa `pm2` (Node) o `gunicorn` (Django) para correr el proceso.
4. **Proxy Inverso**: Configura **Nginx** para redirigir el tráfico del puerto 80 a tu backend (puerto 3000 o 8000).
5. **SSL**: Usa `certbot` para HTTPS gratis.

---
*Nota: Esta ruta requiere mucho más mantenimiento (seguridad, parches, backups) que usar Supabase.*
