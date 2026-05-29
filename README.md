# RallyMatch

バドミントンダブルス試合生成アプリ（主催者: iOS / 参加者: Web SPA）

## 構成

| 領域 | 技術 |
|------|------|
| iOS 主催者 | SwiftUI + SwiftData + Firebase Auth / Firestore |
| 参加者 Web | Vite SPA + Firebase Hosting + Firestore |
| バックエンド | Firestore + Cloud Functions (Scheduler) |

## セットアップ

### 1. Firebase プロジェクト

1. [Firebase Console](https://console.firebase.google.com/) でプロジェクト作成
2. **Authentication** → 匿名ログインを有効化
3. **Firestore** を作成（本番モード推奨）
4. iOS アプリを登録（バンドル ID: `com.take.RallyMatch`）し、**GoogleService-Info.plist** をダウンロード
   - 配置先: `RallyMatch/GoogleService-Info.plist`（`GoogleService-Info.plist.example` では動作しません）
   - Xcode で RallyMatch ターゲットに含まれていることを確認（フォルダ同期のため通常は自動）
5. Web アプリを登録し、設定値を `web/.env` にコピー（`web/.env.example` 参照）

### 2. Web アプリを Firebase に登録（重要）

1. Firebase Console → プロジェクト設定 → **アプリを追加** → **Web**
2. 表示された `appId` を `web/.env` の `VITE_FIREBASE_APP_ID` に設定

### 3. Web（参加者向け）ビルド

```bash
cd web
cp .env.example .env
# .env を編集
npm install
npm run build
```

### 4. デプロイ（必須・QR が動くために必要）

```bash
cd web && npm install && npm run build && cd ..
cd functions && npm install && cd ..
firebase login
firebase deploy
```

Hosting URL（QR用）: `https://rallymatch-e6014.web.app`  
iOS **設定** の URL も同じ値にしてください。

### 5. iOS

1. Xcode で `RallyMatch.xcodeproj` を開く
2. **File → Add Package Dependencies** で `https://github.com/firebase/firebase-ios-sdk` を追加
   - 製品: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseCore`
3. `GoogleService-Info.plist` を `RallyMatch/` に置く（未配置だとクラウド同期不可）
4. **Authentication → 匿名** を有効化
5. アプリ内 **設定** で Hosting の URL を入力（QR 生成用）

## URL 仕様

参加者は次の URL で試合一覧を閲覧します（ログイン不要）。

```
https://{hosting-domain}/session/{sessionId}
```

セッションは **翌日 5:00 (JST)** に Cloud Functions で自動削除されます。

## セキュリティ

- 参加者: Firestore **読み取りのみ**（ルールで公開 read）
- 主催者: 匿名 Auth でログインし、`ownerUid` が一致するセッションのみ書き込み可
- `sessionId` を知っている人は閲覧可能（設計上許容）

## QR を読んでも NotFound になる場合

| 確認項目 | 対処 |
|---------|------|
| Hosting 未デプロイ | `firebase deploy` を実行 |
| iOS の URL が `YOUR_PROJECT.web.app` | 設定で `https://rallymatch-e6014.web.app` に変更 |
| Web アプリ未登録 | Firebase Console で Web アプリを追加し `.env` に appId を設定 |
| 試合生成時に同期エラー | iOS で Firebase 接続を確認し、再生成 |
| Firestore にセッションが無い | [Firebase Console](https://console.firebase.google.com/) → Firestore → `sessions` を確認 |

## ローカル開発

```bash
# Web
cd web && npm run dev

# Firebase エミュレータ（任意）
firebase emulators:start
```
