# Seguridad

## Version 1.0.2

- El instalador contiene el SHA-256 autorizado de su paquete. Cambiar solamente el ZIP y el manifiesto en GitHub no permite que ese instalador acepte otro paquete.
- Se rechazan archivos ZIP inesperados, duplicados, incompletos o de tamano excesivo. Solo se extraen los nombres de aplicacion permitidos.
- Las nuevas descargas de FFmpeg y Deno requieren un SHA-256 publicado por GitHub en el repositorio oficial; si no existe o no coincide, se detienen. yt-dlp mantiene su comprobacion de sumas oficiales.
- Se deshabilita la carga automatica de complementos de yt-dlp y se ignoran configuraciones externas.
- No se solicitan permisos de administrador, contrasenas del navegador ni desactivar el antivirus.

## Limites

No es un antivirus ni una garantia de ausencia de malware. Un archivo multimedia o una vulnerabilidad en FFmpeg, yt-dlp, Deno o Windows puede afectar al equipo. Las comprobaciones de proveedores no protegen frente a un compromiso de esos proveedores. Los componentes ya instalados no se vuelven a autenticar con esta actualizacion.

El instalador no tiene certificado comercial Authenticode. Su hash interno protege el paquete solamente si obtuviste un instalador autentico: si un atacante reemplaza tambien el propio instalador, esta proteccion no basta. No desactives SmartScreen ni el antivirus para instalarlo.

Para una version de aplicacion posterior a 1.0.2 hay que obtener un nuevo instalador con el hash autorizado; el antiguo rechazara la nueva version. Actualizar motor sigue actualizando yt-dlp con sumas oficiales.

## Cuenta y repositorio

El propietario debe proteger su cuenta con una llave de acceso o segundo factor y revisar los accesos de aplicaciones y colaboradores. CODEOWNERS documenta al responsable; por si solo no impide cambios y necesita reglas de proteccion de rama para exigir revision.

No publiques contrasenas, cookies, tokens ni enlaces privados en reportes. Informa de problemas sin incluir datos sensibles mediante los mecanismos de seguridad disponibles en el repositorio.
