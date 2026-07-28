# TryAppleMusicAPI

Apple Music API（MusicKit）を使った再生まわりの検証用 SwiftUI アプリです。  
本アプリ [Breath Trip](https://github.com/CodeCandySchool/MeditationJourney_may) 向けに、楽曲プレビュー取得〜再生制御の実装を試したプロジェクトです。

## できること

- MusicKit による Apple Music へのアクセス許可
- 曲 ID からプレビュー URL を取得
- `AVPlayer` によるプレビュー再生
- 再生時間の選択（1〜60分）
- フェードイン / フェードアウト
- 再生・一時停止

## 技術スタック

- Swift / SwiftUI
- MusicKit（Apple Music API）
- AVFoundation
- Timer による再生時間・フェード制御

## 関連プロジェクト

- [Breath Trip](https://github.com/CodeCandySchool/MeditationJourney_may)
- [TrySpotifyAPI](https://github.com/CodeCandySchool/TrySpotifyAPI_may)

## 補足

テスト・学習用の簡易アプリです。本番アプリへの組み込み前の API 検証を目的としています。
