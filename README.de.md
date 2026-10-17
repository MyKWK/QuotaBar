<div align="center">

# QuotaBar

### Dein KI-Kontingent. Ein Blick genügt.

Codex / GPT · Kimi · Cursor · DeepSeek<br>
Verbleibende KI-Kontingente und Guthaben direkt in der Menüleiste deines Macs.

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Português (Brasil)](README.pt-BR.md)

<img src="docs/images/quotabar-menubar.png" alt="Echter QuotaBar-Screenshot mit unveränderter Menüleiste und weich unkenntlich gemachtem Desktop" width="530">

**Weniger Nutzungsseiten. Mehr Konzentration.**

</div>

Du schreibst Code, wechselst das Modell oder startest einen Task und möchtest wissen, wie viel noch übrig ist. QuotaBar zeigt Service-Symbole und kompakte Werte in der Menüleiste, damit du dein Kontingent prüfen und direkt weiterarbeiten kannst.

![Echter QuotaBar-Screenshot mit unveränderter Menüleiste und weich unkenntlich gemachtem Desktop](docs/images/quotabar-desktop-privacy.png)

<sub>Aufnahme aus der tatsächlichen Nutzung. Die obere Menüleiste enthält die Originalpixel; der übrige Bildschirm wurde weich unkenntlich gemacht, ohne Pixelmosaik. Die Werte gelten für den Aufnahmezeitpunkt. `--` bedeutet, dass kein Messwert vorliegt.</sub>

## Dein Kontingent bleibt im Blick

- **Mehrere Dienste gleichzeitig:** Codex / GPT, Kimi, Cursor und DeepSeek einzeln ein- oder ausblenden.
- **Aussagekräftige Werte:** Codex zeigt den niedrigsten verbleibenden Anteil der verfügbaren Zeitfenster; bei Cursor wählst du Cursor Models oder Other Models; DeepSeek zeigt das tatsächliche verfügbare Guthaben.
- **Native Glasoberfläche:** Panels und Einstellungen mit AppKit, SwiftUI und den Materialien von macOS 27.
- **Lokaler Verlauf:** stündliche SQLite-Stichproben, Auswertungen nach Tag, Woche, Monat, Quartal und Jahr sowie Ringdiagramme und Heatmaps.
- **Erweiterbare Swift-App:** Build mit Swift Package Manager, ohne Laufzeitabhängigkeiten von Drittanbietern.

## Unterstützte Dienste und Aussagekraft

Codex / GPT liest die Nutzung des lokal angemeldeten Codex-Kontos, nicht das allgemeine ChatGPT-Nachrichtenkontingent. Kimi verwendet einen nicht öffentlich dokumentierten Mitgliedschafts-Endpunkt, der sich ändern kann. Cursor nutzt die lokale Anmeldung, DeepSeek einen offiziellen API-Schlüssel. ZCode ist noch nicht implementiert. Das vorhandene Kontenpanel für Claude Code bleibt erhalten; Claude Code ist kein eigener Eintrag in der neuen Menüleiste für mehrere Dienste.

Der Verlauf erfasst Veränderungen zwischen Stichproben in Prozentpunkten, keine Tokenzahlen, Rechnungsbeträge oder Arbeitsstunden. DeepSeek-Guthaben ist noch nicht in den aggregierten Verbrauchsdiagrammen enthalten.

## Erste Schritte

Erforderlich sind **macOS 27+ und Xcode 27.x / Swift 6.4**. Aktuell wird der Quellcode bereitgestellt; für diese Ausgabe gibt es noch kein GitHub-Installationspaket. Öffne nach dem Start die Einstellungen über die Menüleiste und richte die gewünschten Dienste mit deinen eigenen Konten ein.

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

## Datenschutz und Zugangsdaten

Es werden keine nutzbaren Konten oder Schlüssel mitgeliefert. Kimi-Tokens und direkt gespeicherte DeepSeek-Schlüssel liegen lokal in `~/Library/Application Support/QuotaBar/credentials.json`. Die Dateirechte sind `0600`, die Ordnerrechte `0700`: Klartext, der durch Zugriffsrechte geschützt ist. Die übernommene Verwaltung mehrerer Konten verwendet den macOS-Schlüsselbund. Für Abfragen werden die erforderlichen Zugangsdaten an den jeweiligen Dienst gesendet.

[Entwicklung](CONTRIBUTING.md) · [Sicherheit](SECURITY.md) · [Projektherkunft](docs/ORIGINS.md) · [Vollständige Lizenz](LICENSE)

## Eigene Entwicklung und Herkunft des Codes

Das Projekt begann als lokales Kimi-Kontingenttool von MyKWK, das bereits im August 2026 genutzt wurde. Am 16. September wurde bei der Entwicklung für mehrere Dienste Code aus einem anderen gleichnamigen Projekt QuotaBar von Chiloh / chilohwei integriert. Diese Ausgabe verbindet unsere Kimi-Funktionen, das Produktdesign und spätere Erweiterungen mit dieser Codebasis. Sie wird von MyKWK gepflegt.

[Chiloh / chilohwei — QuotaBar](https://github.com/chilohwei/QuotaBar)

Übernommener externer Code behält die Urheberangaben und die vollständige benutzerdefinierte Lizenz. Für persönliche, Bildungs-, Forschungs- und sonstige nichtkommerzielle Zwecke gilt die ursprüngliche Lizenz; kommerzielle Nutzung erfordert die vorherige schriftliche Genehmigung des ursprünglichen Autors. Eine offizielle Unterstützung durch das Ursprungsprojekt oder die KI-Anbieter besteht nicht.

---

Wenn QuotaBar dir Besuche auf Nutzungsseiten erspart, freuen wir uns über einen Star oder dein Feedback.
