<div align="center">

# QuotaBar

### AIの残り枠を、ひと目で。

Codex / GPT · Kimi · Cursor · DeepSeek<br>
Macのメニューバーに、AIサービスの利用枠と残高をまとめて表示。

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md) · **日本語** · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md)

<img src="docs/images/quotabar-menubar.png" alt="QuotaBarの実際のデスクトップ画面。元のメニューバーを保持し、それ以外は強くぼかしています" width="530">

**使用量を探す時間を減らし、作業に集中。**

</div>

コードを書き、モデルを切り替え、タスクを進める。そんなときに知りたいのは「あとどれくらい使えるか」。QuotaBarはサービスのアイコンとコンパクトな数値で残り枠を表示し、使用量のページを何度も開く手間を減らします。

![QuotaBarの実際のデスクトップ画面。元のメニューバーを保持し、それ以外は強くぼかしています](docs/images/quotabar-desktop-privacy.png)

<sub>実際の使用画面です。上部のメニューバーは原画像のまま保持し、それ以外はモザイクを使わず柔らかいぼかしで匿名化しています。数値は撮影時点のもので、`--` はデータ未取得を示します。</sub>

## 残り枠を、いつもの視線の先に

- **複数サービスを同時表示**：Codex / GPT、Kimi、Cursor、DeepSeekの表示を個別に選択。
- **数値の意味が明確**：Codexは取得できた利用枠のうち最小の残り割合、CursorはCursor Models / Other Modelsの選択した枠、DeepSeekは実際の利用可能残高を表示。
- **ネイティブなガラス表現**：AppKit、SwiftUI、macOS 27のガラス素材で、パネルと設定画面を統一。
- **ローカルの利用履歴**：SQLiteで時間ごとに記録し、日・週・月・四半期・年の集計、リングチャート、ヒートマップを表示。
- **拡張できるSwiftアプリ**：Swift Package Managerでビルド。サードパーティ製ランタイムへの依存はありません。

## 対応状況と数値の範囲

Codex / GPTはローカルでログイン済みのCodexアカウントの使用量です。一般的なChatGPTのメッセージ上限ではありません。Kimiは未公開の会員用エンドポイントを利用するため、変更される可能性があります。Cursorはローカルのログイン状態を使用。DeepSeekは公式APIキーで残高を照会します。ZCodeは未実装です。Claude Codeは既存のアカウントパネルを維持していますが、新しい複数サービス用メニューバーの個別項目には含まれません。

履歴はサンプル間の利用枠の変化をパーセントポイントで示します。トークン数、請求額、作業時間ではありません。DeepSeekの残高は消費量の集計グラフにはまだ含まれません。

## 使い始める

**macOS 27以降、Xcode 27.x / Swift 6.4**が必要です。現在はソースコードを公開しており、このカスタム版のGitHub配布用インストーラーは未公開です。起動後はメニューバーから設定を開き、サービスと自分のアカウントを設定してください。

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

## プライバシーと認証情報

利用可能なアカウントやキーは同梱していません。Kimiのトークンと直接保存したDeepSeekキーは、ローカルの `~/Library/Application Support/QuotaBar/credentials.json` に保存されます。ファイル権限は `0600`、ディレクトリ権限は `0700` で、権限で保護された平文です。既存の複数アカウント機能はmacOS Keychainを使用します。照会に必要な認証情報は、対応するサービスへ送信されます。

[開発ガイド](CONTRIBUTING.md) · [セキュリティ](SECURITY.md) · [開発の経緯](docs/ORIGINS.md) · [ライセンス全文](LICENSE)

## 開発の経緯とコードの出典

このプロジェクトは、MyKWKが2026年8月から利用していたローカルのKimi利用枠ツールから始まりました。9月16日の複数サービス対応の開発で、Chiloh / chilohweiによる別の同名プロジェクトQuotaBarのコードを導入し、私たちのKimi機能、製品設計、その後の拡張と統合しました。本版はMyKWKが保守しています。

[Chiloh / chilohwei — QuotaBar](https://github.com/chilohwei/QuotaBar)

利用した外部コードの著作権表示とカスタムライセンスを保持しています。個人・教育・研究などの非商用利用は元のライセンスに従い、商用利用には原著作者の事前の書面による許可が必要です。上流プロジェクトや各サービスによる公式な承認・推薦を示すものではありません。

---

使用量ページを開く回数が減ったら、Starやフィードバックで応援していただけるとうれしいです。
