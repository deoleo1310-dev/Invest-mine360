# 🌍 Guía de Despliegue (Deployment)

Opciones recomendadas para desplegar InvestPro gratis.

## Opción 1: Netlify (Recomendada)

1. **Preparar Repositorio**: Sube tu código a GitHub.
2. **Crear cuenta en Netlify**: Ve a [netlify.com](https://netlify.com).
3. **Nuevo Sitio**: Click en "Add new site" -> "Import an existing project".
4. **Conectar GitHub**: Selecciona tu repositorio `investpro`.
5. **Configuración de Build**:
   - **Build command**: `yarn build`
   - **Publish directory**: `dist`
6. **Variables de Entorno (IMPORTANTE)**:
   - En la configuración de Netlify, busca "Environment variables".
   - Agrega `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` con tus valores reales.
7. **Deploy**: Click en "Deploy site".

## Opción 2: Vercel

1. **Instalar Vercel CLI** (opcional) o ir a [vercel.com](https://vercel.com).
2. **Importar Proyecto**: Selecciona tu repo de GitHub.
3. **Configuración**: Vercel detecta Vite automáticamente.
4. **Variables de Entorno**:
   - Agrega las mismas variables `VITE_SUPABASE_...` en la sección de configuración.
5. **Deploy**.

## Mantenimiento y Optimización

### Mantenimiento
- **Backups**: Supabase realiza backups diarios automáticos (en plan Pro) o puedes exportar la data desde el dashboard.
- **Logs**: Revisa los logs de Auth en Supabase si los usuarios reportan problemas de acceso.

### Escalabilidad
- El código está optimizado con `React.lazy` (si se requiere) y Vite.
- Supabase escala automáticamente. Si tienes miles de usuarios, considera agregar índices en `user_id` en las tablas (ya incluidos en el script inicial).
