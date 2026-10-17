<div align="center">

# QuotaBar

### Tu cuota de IA, de un vistazo.

Codex / GPT · Kimi · Cursor · DeepSeek<br>
Las cuotas y los saldos de tus servicios de IA, en la barra de menús del Mac.

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md)

<img src="docs/images/quotabar-menubar.png" alt="Captura real de QuotaBar con la barra de menús original y el resto de la pantalla desenfocado" width="530">

**Menos pestañas de consumo. Más concentración.**

</div>

Mientras programas, cambias de modelo o ejecutas tareas, solo quieres saber cuánto te queda. QuotaBar reúne iconos de servicios y cifras compactas en la barra de menús para que puedas consultar tu cuota y seguir trabajando.

![Captura real de QuotaBar con la barra de menús original y el resto de la pantalla desenfocado](docs/images/quotabar-desktop-privacy.png)

<sub>Captura de uso real. La barra superior conserva los píxeles originales; el resto se ha anonimizado con un desenfoque suave, sin pixelado. Las cifras corresponden al momento de la captura; `--` indica que no hay datos disponibles.</sub>

## Tu cuota, siempre a la vista

- **Varios servicios a la vez:** muestra u oculta Codex / GPT, Kimi, Cursor y DeepSeek por separado.
- **Cifras con significado:** Codex muestra el menor porcentaje restante entre las ventanas disponibles; Cursor permite elegir Cursor Models u Other Models; DeepSeek muestra el saldo disponible real.
- **Interfaz de cristal nativa:** paneles y ajustes con AppKit, SwiftUI y los materiales de macOS 27.
- **Historial local:** muestras horarias en SQLite, resúmenes por día, semana, mes, trimestre y año, gráficos de anillo y mapas de calor.
- **Swift extensible:** compilación con Swift Package Manager, sin dependencias de ejecución de terceros.

## Servicios y alcance de los datos

Codex / GPT consulta la cuenta de Codex iniciada en este Mac, no la cuota general de mensajes de ChatGPT. Kimi usa un endpoint de membresía sin documentación pública que puede cambiar. Cursor usa la sesión local y DeepSeek una API Key oficial. ZCode aún no está implementado. Se conserva el panel de cuentas de Claude Code, pero no aparece como servicio independiente en la nueva barra multiservicio.

El historial refleja cambios en puntos porcentuales entre muestras, no tokens, importes facturados ni horas trabajadas. El saldo de DeepSeek aún no se incluye en los gráficos de consumo agregado.

## Primeros pasos

Requiere **macOS 27+ y Xcode 27.x / Swift 6.4**. Actualmente se distribuye el código fuente; todavía no hay un instalador de esta edición en GitHub. Tras ejecutarla, abre los ajustes desde la barra de menús, elige los servicios y configura tus propias cuentas.

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

## Privacidad y credenciales

No se incluyen cuentas ni claves utilizables. Los tokens de Kimi y las claves de DeepSeek guardadas directamente se almacenan en `~/Library/Application Support/QuotaBar/credentials.json`: archivo con permisos `0600` y directorio `0700`. Es texto sin cifrar protegido por permisos. Las credenciales de la gestión de varias cuentas heredada usan macOS Keychain. Las consultas envían las credenciales necesarias al servicio correspondiente.

[Desarrollo](CONTRIBUTING.md) · [Seguridad](SECURITY.md) · [Procedencia](docs/ORIGINS.md) · [Licencia completa](LICENSE)

## Trabajo original y procedencia del código

El proyecto comenzó como una herramienta local de cuota de Kimi de MyKWK, ya en uso en agosto de 2026. El 16 de septiembre, durante el desarrollo multiservicio, se incorporó código de otro proyecto homónimo, QuotaBar, mantenido por Chiloh / chilohwei. Esta edición combina nuestro trabajo en Kimi, el diseño del producto y las ampliaciones posteriores con esa base de código. La mantiene MyKWK.

[Chiloh / chilohwei — QuotaBar](https://github.com/chilohwei/QuotaBar)

El código externo utilizado conserva su atribución y su licencia personalizada íntegra. El uso personal, educativo, de investigación y otros usos no comerciales se rigen por la licencia original; el uso comercial requiere autorización previa por escrito del autor original. No implica respaldo oficial del proyecto de origen ni de los proveedores de IA.

---

Si QuotaBar te ahorra visitas a las páginas de consumo, dale una Star o comparte tus comentarios.
