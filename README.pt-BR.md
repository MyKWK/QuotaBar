<div align="center">

# QuotaBar

### Sua cota de IA, em um olhar.

Codex / GPT · Kimi · Cursor · DeepSeek<br>
Cotas e saldos dos seus serviços de IA na barra de menus do Mac.

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português (Brasil)**

<img src="docs/images/quotabar-menubar.png" alt="Captura real do QuotaBar com a barra de menus original e o restante da tela desfocado" width="530">

**Menos abas de consumo. Mais foco no que você está fazendo.**

</div>

Entre escrever código, trocar de modelo e executar tarefas, você só quer saber quanto ainda pode usar. O QuotaBar reúne ícones e números compactos na barra de menus para você conferir suas cotas e continuar trabalhando.

![Captura real do QuotaBar com a barra de menus original e o restante da tela desfocado](docs/images/quotabar-desktop-privacy.png)

<sub>Captura de uso real. A barra superior mantém os pixels originais; o restante foi anonimizado com um desfoque suave, sem mosaico. Os valores são do momento da captura; `--` indica que não há dados disponíveis.</sub>

## Suas cotas sempre à vista

- **Vários serviços ao mesmo tempo:** mostre ou oculte Codex / GPT, Kimi, Cursor e DeepSeek individualmente.
- **Números com significado:** o Codex mostra a menor porcentagem restante entre as janelas disponíveis; no Cursor, escolha Cursor Models ou Other Models; o DeepSeek mostra o saldo disponível real.
- **Interface de vidro nativa:** painéis e ajustes com AppKit, SwiftUI e os materiais do macOS 27.
- **Histórico local:** amostras por hora no SQLite, resumos por dia, semana, mês, trimestre e ano, gráficos de rosca e mapas de calor.
- **App Swift extensível:** compilação com Swift Package Manager, sem dependências de terceiros em tempo de execução.

## Serviços e alcance dos dados

Codex / GPT usa os dados da conta do Codex conectada neste Mac, não a cota geral de mensagens do ChatGPT. O Kimi usa um endpoint de assinatura sem documentação pública, que pode mudar. O Cursor usa a sessão local; o DeepSeek usa uma chave de API oficial. O ZCode ainda não foi implementado. O painel de contas do Claude Code foi mantido, mas ele não é um item separado na nova barra de menus com vários serviços.

O histórico representa mudanças em pontos percentuais entre amostras, não tokens, valores cobrados ou horas trabalhadas. Os saldos do DeepSeek ainda não entram nos gráficos de consumo agregado.

## Primeiros passos

Requer **macOS 27+ e Xcode 27.x / Swift 6.4**. No momento, o código-fonte está disponível; ainda não há instalador desta edição no GitHub. Após executar o app, abra os ajustes pela barra de menus, escolha os serviços e configure suas próprias contas.

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

## Privacidade e credenciais

Nenhuma conta ou chave utilizável é incluída. Os tokens do Kimi e as chaves do DeepSeek salvas diretamente ficam em `~/Library/Application Support/QuotaBar/credentials.json`, com permissões `0600` para o arquivo e `0700` para a pasta. É texto sem criptografia, protegido por permissões. As credenciais do gerenciamento herdado de várias contas usam o Acesso às Chaves do macOS. As consultas enviam as credenciais necessárias ao serviço correspondente.

[Desenvolvimento](CONTRIBUTING.md) · [Segurança](SECURITY.md) · [Origem do projeto](docs/ORIGINS.md) · [Licença completa](LICENSE)

## Trabalho original e origem do código

O projeto começou como uma ferramenta local de cota do Kimi criada por MyKWK, já em uso em agosto de 2026. Em 16 de setembro, o desenvolvimento para vários serviços incorporou código de outro projeto com o mesmo nome, QuotaBar, mantido por Chiloh / chilohwei. Esta edição combina nosso trabalho no Kimi, o design do produto e as ampliações posteriores com essa base de código. A manutenção é feita por MyKWK.

[Chiloh / chilohwei — QuotaBar](https://github.com/chilohwei/QuotaBar)

O código externo utilizado mantém a atribuição e a licença personalizada completas. O uso pessoal, educacional, de pesquisa e outros usos não comerciais seguem a licença original; o uso comercial exige autorização prévia por escrito do autor original. Não há endosso oficial do projeto de origem nem dos provedores de IA.

---

Se o QuotaBar poupa algumas visitas às páginas de consumo, deixe uma Star ou compartilhe sua experiência.
