//
//  ContentView.swift
//  TryAppleMusicAPI
//
//  Created by apple on 2024/12/01.
//

import SwiftUI

import SwiftUI
import MusicKit
import AVFoundation


struct ContentView: View {
    /// 状態を管理する列挙体
    enum Status {
        // 再生中
        case playing
        // 停止
        case stopped
        // 一時停止
        case paused
    }
    /// タイマーの状態　初期は.stopped
    @State private var state: Status = .stopped
    /// プレビューURL
    @State private var previewURL: URL?
    /// 再生状態
    @State private var isPlaying = false
    /// プレイヤー
    @State private var player: AVPlayer?
    /// ロード状態を管理する変数
    @State private var isLoading = false
    /// 通知の名前
    let notificationName = Notification.Name("notificationName")
    /// 初期値を1分とする
    @State private var selectedTime: Int = 1
    /// ユーザーが選択する時間のタイマー
    @State private var selectedTimer: Timer?
    /// ユーザーが選択する時間のタイマーの終了時刻
    @State private var endTime: Date?
    /// 音再生のタイマー
    @State private var soundTimer: Timer?
    /// 表示秒数(タイマーの時間)
    @State private var displayTime: TimeInterval = 0
    /// スタート時間
    @State private var startTime: Date?
    /// 一時停止時の経過時間
    @State private var elapsedTime: TimeInterval = 0
    /// 残り時間
    @State private var remainingTime: TimeInterval = 0
    /// fadeInを管理
    @State private var isFadeIn = false
    /// fadeOutを管理
    @State private var isFadeOut = false
    /// fadeInのタイマー
    @State private var fadeInTimer: Timer?
    /// fadeOutのタイマー
    @State private var fadeOutTimer: Timer?
    /// fadeOutの終了時間を管理する変数
    @State private var fadeOutEndTime: Date?
    /// fadeOutの秒数を管理する変数（初期値は30.0）
    @State private var fadeOutTime: TimeInterval = 30.0
    /// fadeOutを修了するタイマー
    @State private var fadeOutEndTimer: Timer?
    //    <iframe allow="autoplay *; encrypted-media *;" frameborder="0" height="150" style="width:100%;max-width:660px;overflow:hidden;background:transparent;" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation" src="https://embed.music.apple.com/jp/album/%E9%8A%80%E6%B2%B3%E9%89%84%E9%81%93999/477643015?i=477643022"></iframe>
    //    <iframe allow="autoplay *; encrypted-media *;" frameborder="0" height="150" style="width:100%;max-width:660px;overflow:hidden;background:transparent;" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation" src="https://embed.music.apple.com/jp/album/%E7%B2%95%E6%AF%9B%E5%B7%9D-%E3%81%9B%E3%81%9B%E3%82%89%E3%81%8E/259872642?i=259872743"></iframe>
    // <iframe allow="autoplay *; encrypted-media *;" frameborder="0" height="150" style="width:100%;max-width:660px;overflow:hidden;background:transparent;" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation" src="https://embed.music.apple.com/jp/album/%E3%82%B5%E3%83%89%E3%82%A5%E3%83%B3%E3%83%AA%E3%83%BC-%E3%82%A2%E3%82%A4-%E3%82%B7%E3%83%BC/724916985?i=724917482"></iframe>
    // 設定画面へ誘導するアラート
    @State private var isShowAlert = false
    private let iD: String = "724917482"
    var body: some View {
        VStack {
            // isLoadingがtrueなら
            if isLoading {
                // ローディング中
                ProgressView("Loading...")
                // falseなら
            } else {
                Picker("再生時間を選択", selection: $selectedTime) {
                    Text("1分").tag(1)
                    Text("3分").tag(3)
                    Text("5分").tag(5)
                    Text("10分").tag(10)
                    Text("20分").tag(20)
                    Text("30分").tag(30)
                    Text("40分").tag(40)
                    Text("50分").tag(50)
                    Text("60分").tag(60)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(height: 150)
                Text("\(Int(displayTime))秒")
                // ボタンを表示
                Button(action: {
                    if previewURL != nil {
                        updateState(newState: .playing)
                    } else {
                        print("previewURLがないため再生できません")
                    }
                }) {
                    Text("再生")
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(isPlaying)
                // ボタンを表示
                Button(action: {
                    updateState(newState: .paused)
                }) {
                    // isPlayingがtrueのときは停止、falseのときは再生を表示
                    Text("一時停止")
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .disabled(state == .paused)
                // Preview URLをとるよう表示
                Button("PreviewURLを取得する") {
                    // fetchPreciewURLを非同期処理
                    Task {
                        await fetchPreviewURL(for: iD)
                    }
                }
                .frame(width: 200, height: 50)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(previewURL != nil)
            } // if isLoading
        } // VStack
        .alert(isPresented: $isShowAlert) {
            Alert(
                title: Text("メディアとApple Musicへのアクセスがオフになっています"),
                message: Text("この機能を使うにはメディアとApple Musicへのアクセスをオンにしてください。設定アプリで変更できます。"),
                primaryButton: .default(Text("設定を開く")) {
                    // 設定アプリの自›分のアプリの設定画面を開く
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                },
                secondaryButton: .cancel(Text("キャンセル"))
            ) // Alert
        } // .alertここまで
        .onAppear {
            stopSelectedTimer()
            stopFadeOutEndTimer()
            displayTime = Double(selectedTime * 60)
        } // .onAppear
        .onChange(of: selectedTime) {
            displayTime = Double(selectedTime * 60)
        } // .onChange
        .onChange(of: displayTime) {
            // displayTimeが5秒になったらフェードアウトをする
            if displayTime >= 5 && displayTime < 5.1  {
//                // fadeOutEndTimerを無効にする
//                stopFadeOutEndTimer()
                // フェードアウトする
                fadeOut(player: player!, duration: 5)
            } // if displayTime
        }
        // 再生完了（音量0）の通知を受け取る
        .onReceive(NotificationCenter.default.publisher(for: notificationName)) { _ in
            print("音量が0になりました。")
            if let endTime = endTime, Date() < endTime && displayTime > 10 {
                print("再度再生します。")
                // fadeOutEndTimerを無効にする
                stopFadeOutEndTimer()
                // 30秒を入れ直す
                fadeOutTime = 30.0
                // fadeOutの終了時刻は、fadeOutTimeを考慮
                fadeOutEndTime = Date().addingTimeInterval(fadeOutTime)
                // 音量が0になったら再生
                playBack()
            } else if let endTime = endTime, Date() > endTime && displayTime < 1 {
                print("⚠️状態がストップになりました⚠️")
                updateState(newState: .stopped)
            } else if let endTime = endTime, Date() < endTime && displayTime <= 10 && displayTime >= 1 {
                player?.volume = 0.3
                player?.play()
            } // if let endTime...
        } // .onReceive
    } // body
    func startPlayAndTimer() {
        // 多重でタイマーを開始しないようにする
        stopSelectedTimer()
        // 終了時刻は、残り時間を考慮
        endTime = Date().addingTimeInterval(displayTime)
        // fadeOutの終了時刻は、fadeOutTimeを考慮
        fadeOutEndTime = Date().addingTimeInterval(fadeOutTime)
        print("現在時刻は\(Date())")
        print("終了時刻を計算すると\(String(describing: endTime))")
        print("fadeOutEndTimeを計算すると\(String(describing: fadeOutEndTime))")
        // 再生を開始
        playBack()
        // タイマーを開始
        startTimer()
        print("タイマーは\(endTime!)で終わり")
    }
    
    func startTimer() {
        // displayTimeが0よりも小さければ処理しない
        guard displayTime > 0 else {
            return
        }
        if let endTime = endTime {
            selectedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                // 現在時刻
                let now = Date()
                // 現在時刻と終了時刻の差を評価し、0以上の値を返す
                displayTime = max(0, endTime.timeIntervalSince(now))
                print(displayTime)
                // displayTimeが0以下のとき
                if displayTime <= 0 {
                    // タイマーが終了したらタイマーとfadeOutTimerを停止
                    stopSelectedTimer()
                }
            }// selectedTimer
        } // if let
    } // startTimer
    // func stopTimer
    func stopSelectedTimer() {
        // selectedTimerを無効化
        selectedTimer?.invalidate()
        // selectedTimerをnil
        selectedTimer = nil
    } // stopTimer
    // func stopFadeOutEndTimer
    func stopFadeOutEndTimer() {
        // isFadeOutをfalse
        isFadeOut = false
        // fadeOutEndTimerを無効化
        fadeOutEndTimer?.invalidate()
        // fadeOutEndTimerをnil
        fadeOutEndTimer = nil
        print("❎fadeOutEndTimerを削除しました❎")
    } // func stopFadeOutEndTimer
    // 状態更新
    func updateState(newState: Status) {
        // newStateが以下の状態となる場合
        switch newState {
            // 再生状態になったら
        case .playing:
            //
            isPlaying = true
            startPlayAndTimer()
        case .stopped:
            //
            isPlaying = false
            // 曲を停止
            player?.pause()
            // 30秒を入れ直す
            fadeOutTime = 30.0
            // playerをnilに
            player = nil
            // タイマー停止
            stopSelectedTimer()
            // fadeOutEndTimerを無効、nilにする
            stopFadeOutEndTimer()
        case .paused:
            //
            isPlaying = false
            // 曲を一時停止
            player?.pause()
            // ストップ
            stopSelectedTimer()
            // fadeOutEndTimerを無効、nilにする
            stopFadeOutEndTimer()
            // フェードアウトタイマーを無効
            fadeOutTimer?.invalidate()
        } // switch newState
        state = newState
    }
    // fetchPreviewURL
    func fetchPreviewURL(for trackID: String) async {
        // エラーを出すメソッドを安全に返す(request)
        do {
            // Apple Musicの認証ステータス
            let musicAuthorizationStatus = await MusicAuthorization.request()
            // 認証されなかったら
            guard musicAuthorizationStatus == .authorized else {
                // アラート表示
                isShowAlert = true
                // 処理終了　なにもしない
                print("許可されませんでした")
                return
            } // guard musicAuthorizationStatus
            // 楽曲IDを指定してリクエストを作成
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(trackID))
            // レスポンスを取得
            let response = try await request.response()
            // 曲とプレビューURLが存在する場合
            if let song = response.items.first,
               let previewURL = song.previewAssets?.first?.url {
                // previewURLに代入
                self.previewURL = previewURL
                print("previewURLの取得完了！")
            } // if let
            // エラーの場合
        } catch {
            print("指定したトラックID（\(trackID)）の曲とpreviewURLがありません")
            print("エラーはこちら: \(error)")
            return
        } // do catch
    } // fetchPreciewURL
    // 曲を再生するメソッド
    private func playBack() {
        // previewURLが存在しなかったら何もしない
        guard let previewURL = previewURL,
              let endTime = endTime,
              let fadeOutEndTime = fadeOutEndTime else {
            // プレビューURLが存在しなかったらコメント
            print("previewURLが存在しません")
            return
        }
        // playerがnilのとき（初めての再生のとき）
        if player == nil {
            print("🙆新しいプレーヤーを取得しました！")
            // playerにpreviewUrlを代入する
            player = AVPlayer(url: previewURL)
            // 再生する
            player?.play()
            // フェードイン
            fadeIn(player: player!, duration: 5)
        } else {
            // 再開したとき
            // 再生するのみ
            player?.play()
        }
        // フェードアウト
        fadeOutEndTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // 現在時刻
            let now = Date()
            fadeOutTime = max(0, fadeOutEndTime.timeIntervalSince(now))
            print("❤️フェードアウトのタイマーは\(fadeOutTime)")
            // fadeOutEndTimeの5秒前になったら
            if fadeOutTime >= 5 && fadeOutTime < 5.1 {
                // 5秒かけてフェードアウト
                fadeOut(player: player!, duration: 5.0)
            } else if fadeOutTime < 5 && fadeOutTime > 0 {
                // 残り時間をかけてフェードアウト
                fadeOut(player: player!, duration: fadeOutTime)
            }
        } // fadeOutEndTimer
        print("⭐️previewURLはこちら\(previewURL)")
    } // func playBack()
    // 自然に聞こえるフェードイン
    func fadeIn(player: AVPlayer, duration: TimeInterval) {
        // もしisFadeOutがtrueまたはdisplayTimeが10秒以下なら
        if isFadeOut || displayTime <= 10 {
            // フェードインしない
            return
        }
        isFadeIn = true
        let fadeDuration = duration
        // 100ミリ秒ごとに音量を変更
        let interval: TimeInterval = 0.1
        let totalSteps = Int(fadeDuration / interval)
        var currentStep = 0
        fadeInTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if currentStep < totalSteps {
                // 音量の変更を指数関数的に調整
                let normalizedTime = Double(currentStep) / Double(totalSteps)
                // 2乗することで、初期はゆっくり、後半は急激に上昇
                player.volume = Float(pow(normalizedTime, 2))
                currentStep += 1
            } else {
                // 最大音量に設定
                player.volume = 1.0
                timer.invalidate()
                fadeInTimer = nil
            } // if
        } // fadeInTimer
    } // func fadeIn
    // 自然に聞こえるフェードアウト
    func fadeOut(player: AVPlayer, duration: TimeInterval) {
        print("🧡fadeOut関数をたたいたよ！")
        // フェードアウトしているとき
        if isFadeOut == true {
            print("💚isFadeOutがtrueなので処理なし")
            // 何も処理しない
            return
        } // if isFadeOut...
        isFadeOut = true
        let fadeDuration = duration
        let interval: TimeInterval = 0.1
        let totalSteps = Int(fadeDuration / interval)
        var currentStep = 0
        
        // 現在の音量を開始音量とする
        let startVolume = player.volume
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if currentStep < totalSteps {
                // 音量の変更を指数関数的に調整
                let normalizedTime = Double(currentStep) / Double(totalSteps)
                // フェードインとは逆に音量が徐々に減少
                player.volume = Float(startVolume * pow(Float(1.0 - normalizedTime), 2))
                currentStep += 1
            } else {
                // 音量をゼロに設定
                player.volume = 0.0
                player.pause()
                self.player = nil
                timer.invalidate()
                isFadeOut = false
                isPlaying = false
                // フェードアウトが終わったら通知を送信
                NotificationCenter.default.post(name: notificationName, object: nil)
            } // if currentStep
        } // Timer
    } // func fadeOut
} // ContentView


#Preview {
    ContentView()
}

