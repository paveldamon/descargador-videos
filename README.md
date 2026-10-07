# Descargador de videos

Aplicacion de escritorio para Windows de Pavel Damon.

## Uso

**[Descargar instalador para Windows](https://github.com/paveldamon/descargador-videos/raw/refs/heads/main/dist/Instalar-Descargador.exe)**

Abre `Instalar-Descargador.exe` y pulsa **Instalar**. Descarga la version publicada en este repositorio, verifica su SHA-256 y crea accesos directos en el escritorio y el menu Inicio. Se instala para tu usuario, sin permisos de administrador. El instalador necesita conexion a Internet.

Tambien puedes descargar el **[paquete portable](https://github.com/paveldamon/descargador-videos/raw/refs/heads/main/dist/Descargador-1.0.2.zip)** y extraerlo completo.

Abre `Descargador/Descargador.exe`, pega el enlace, elige la calidad y pulsa **Descargar**. Conserva todos los archivos de la carpeta junto al ejecutable.

La primera descarga prepara yt-dlp, FFmpeg y Deno desde sus repositorios oficiales. Necesita Internet y Windows 10/11 de 64 bits. No requiere instalar Python.

## Funciones

- Video MP4 compatible con H.264 y AAC; conversion cuando sea necesaria.
- Seleccion de calidad y opcion explicita de audio MP3.
- Carpeta de destino, progreso, cancelacion y actualizacion del motor.
- Limpieza del enlace al terminar correctamente.
- Reintento por IPv4 cuando falla la resolucion del sitio.

La compatibilidad depende del sitio y del enlace. No admite DRM ni inicio de sesion para contenido privado. Usa contenido propio o autorizado.

## Codigo

La interfaz esta escrita en PowerShell y Windows Forms. El iniciador del ejecutable esta escrito en C#.

| Archivo | Funcion |
| --- | --- |
| Descargador.ps1 | Interfaz |
| Worker.ps1 | Descargas y componentes |
| Video.ps1 | Seleccion, verificacion y conversion |
| Enlaces.ps1 | Normalizacion de enlaces |
| Iniciar.cs | Iniciador del programa |
| CrearLogo.ps1 | Generacion del logo |

Puedes ejecutar `Descargador/Abrir.cmd` para usar directamente los scripts.

El codigo C# del instalador esta en `Instalador/Instalador.cs`. `Instalador/Compilar.cmd` lo recompila en Windows con .NET Framework. El archivo `dist/latest.json` indica el paquete y su SHA-256. Para publicar una nueva version, sube un ZIP con una carpeta `Descargador` que contenga los mismos archivos de aplicacion y actualiza el manifiesto en el mismo commit. No incluyas registros, componentes descargados ni videos. El instalador conserva las carpetas `bin`, `cache` y `Descargas` al reinstalar. La actualizacion de la aplicacion se realiza volviendo a ejecutar el instalador; **Actualizar motor** solo actualiza yt-dlp.

## Componentes externos

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [FFmpeg Builds](https://github.com/yt-dlp/FFmpeg-Builds)
- [Deno](https://github.com/denoland/deno)

Estos componentes se descargan al usar el programa y mantienen sus respectivas licencias.

© 2026 Pavel Damon


## Protecciones de la version 1.0.2

Consulta [SECURITY.md](SECURITY.md). El instalador valida un hash autorizado incrustado; para nuevas versiones descarga un instalador nuevo de confianza. Esto no reemplaza al antivirus ni protege un instalador que ya fue modificado. Las nuevas descargas de FFmpeg y Deno requieren verificacion SHA-256 del proveedor.
