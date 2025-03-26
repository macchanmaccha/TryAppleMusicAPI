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
    /// 再生状態を管理する列挙体
    enum PlaybackState {
        // 再生中
        case playing
        // 停止
        case stopped
        // 一時停止
        case paused
    } // enum Status
    /// タイマーの状態　初期は.stopped
    @State private var state: PlaybackState = .stopped
    /// プレビューURL
    @State private var previewURL: URL?
    /// プレイヤー
    @State private var audioPlayer: AVPlayer?
    /// 初期値を1分とする
    @State private var selectedTime: Int = 1
    /// ユーザーが選択する時間のタイマー
    @State private var selectedDurationMinutes: Timer?
    /// ユーザーが選択する時間のタイマーの終了時刻
    @State private var endTime: Date?
    /// 表示秒数(タイマーの時間)
    @State private var remainingTime: TimeInterval = 0
    /// fadeInを管理
    @State private var isFadeIn = false
    /// fadeOutを管理isFadeOut
    @State private var fadeInTimer: Timer?
    /// fadeOutのタイマー
    @State private var fadeOutTimer: Timer?
    /// fadeOutの終了時間を管理する変数
    @State private var fadeOutEndTime: Date?
    /// fadeOutの秒数を管理する変数（初期値は30.0）
    @State private var fadeOutTime: TimeInterval = 30.0
    /// fadeOutを終了するタイマー
    @State private var fadeOutEndTimer: Timer?
    
    //    <iframe allow="autoplay *; encrypted-media *;" frameborder="0" height="150" style="width:100%;max-width:660px;overflow:hidden;background:transparent;" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation" src="https://embed.music.apple.com/jp/album/%E7%B2%95%E6%AF%9B%E5%B7%9D-%E3%81%9B%E3%81%9B%E3%82%89%E3%81%8E/259872642?i=259872743"></iframe>
    /// 設定画面へ誘導するアラート
    @State private var isShowAlert = false
    
    /// フェードアウトが終わった後の通知の名前
    private let fadeOutNotification = Notification.Name("fadeOutNotification")
    /// 曲のID
    private let trackID: String = "259872743"
    /// 再生ボタンの背景色
    private var playBackButtonBackground: Color {
        (previewURL != nil) && state != .playing && remainingTime != 0 ? .blue : .gray
    }
    /// 再生ボタンを非活性にする条件
    private var isPlayBackButtonDisabled: Bool {
        // previewURLがない時またはstateがplayingまたはstateがstoppedかつremainingTimeが0秒のとき再生ボタンを無効化
        previewURL == nil || state == .playing || state == .stopped && remainingTime == 0
    }
    /// 一時停止ボタンの背景色
    private var pauseButtonBackground: Color {
        state == .playing ? .red : .gray
    }
    /// 一時停止ボタンを非活性にする条件
    private var isPauseButtonDisabled: Bool {
        // 再生状態がpauseのときや、stoppedのとき
        state == .paused || state == .stopped
    }
    var body: some View {
        VStack {
            // 音再生の時間を選択するPicker
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
            // 表示時間
            Text("\(Int(remainingTime))秒")
            // 再生ボタン
            Button(action: {
                // プレビューURLが存在したら
                if previewURL != nil {
                    print("❄️再生が押されたよ！❄️")
                    // 再生状態をplayingにする
                    updateState(newState: .playing)
                } else {
                    // プレビューURLが存在しなかったら
                    print("previewURLがないため再生できません")
                } // if previewURL
            }) {
                Text("再生")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(playBackButtonBackground)
                    .cornerRadius(10)
            }
            .disabled(isPlayBackButtonDisabled)
            // 一時停止ボタン
            Button(action: {
                // 再生状態をpausedに
                updateState(newState: .paused)
            }) {
                Text("一時停止")
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(pauseButtonBackground)
                    .cornerRadius(10)
            } // Button
            // ボタンを無効
            .disabled(isPauseButtonDisabled)
        } // VStack
        // AppleMusicへのアクセスが許可されなかった時に、設定画面への遷移を促すアラート
        .alert(isPresented: $isShowAlert) {
            Alert(
                title: Text("メディアとApple Musicへのアクセスがオフになっています"),
                message: Text("この機能を使うにはメディアとApple Musicへのアクセスをオンにしてください。設定アプリで変更できます。"),
                primaryButton: .default(Text("設定を開く")) {
                    // 設定アプリの自分のアプリの設定画面を開く
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                },
                secondaryButton: .cancel(Text("キャンセル"))
            ) // Alert
        } // .alertここまで
        // 画面が表示された時に行う処理
        .onAppear {
            // selectedTimerを無効、nilに
            stopSelectedTimer()
            // fadeOutEndTimerを無効、nilに
            stopFadeOutEndTimer()
            // remainingTimeにユーザーが選択した分数✖️60秒の数を格納
            remainingTime = Double(selectedTime * 60)
            Task {
                await fetchPreviewURL(for: trackID)
            }
        } // .onAppear
        // selectedTimeの変更を検知
        .onChange(of: selectedTime) {
            // ユーザーが選択した分数✖️60秒の数を格納
            remainingTime = Double(selectedTime * 60)
        } // .onChange
        // remainingTimeの変更を検知
        .onChange(of: remainingTime) {
            // remainingTimeが5秒になったら必ずフェードアウトをする
            // なお、remainingTimeはTimeInterval型（Double型）のため、5.0〜5.1秒間で範囲指定
            if remainingTime >= 5.0 && remainingTime < 5.1  {
                // playerが存在したら
                if audioPlayer != nil {
                    // フェードアウトする
                    fadeOut(player: audioPlayer!, duration: 5)
                } else {
                    // playerが存在しなかったら
                    // fadeOutEndTimeを無効、nilとする
                    stopFadeOutEndTimer()
                    // その後は処理終了とする
                    return
                } // if remainingTime
                // remainingTimeが0以下になったら
            } else if remainingTime <= 0 {
                // 再生状態をstoppedにする
                updateState(newState: .stopped)
            }// if remainingTime
        } // .onChange(of: remainingTime)
        // 再生完了（音量0）の通知を受け取る
        .onReceive(NotificationCenter.default.publisher(for: fadeOutNotification)) { _ in
            print("音量が0になりました。")
            // endTimeが存在しない場合は何もしない
            guard let endTime else {
                return
            }
            // 終了時間が未到来の場合
            if Date() < endTime {
                // remainingTimeが10より大きい場合
                if remainingTime > 10 {
                    print("再度再生します。")
                    // fadeOutEndTimerを無効、nilにする
                    stopFadeOutEndTimer()
                    // fadeOutTimeに30を格納（30秒後をフェードアウト終了時間とするため）
                    fadeOutTime = 30
                    // fadeOutの終了時刻は、1行上で30を入れたfadeOutTimeを考慮
                    fadeOutEndTime = Date().addingTimeInterval(fadeOutTime)
                    // 再生
                    playBack()
                    // remainingTimeが1以上1O以下の場合
                } else if remainingTime >= 1 && remainingTime <= 10 {
                    print("🐻1~10のときの処理にはいってるよ！🐻")
                    return
                }// if remainingTime > 10
                // 終了時刻が到来済の場合
            } else if Date() >= endTime {
                if remainingTime < 1 {
                    print("⚠️状態がストップになりました⚠️")
                    // 状態をstoppedにする
                    updateState(newState: .stopped)
                }
            }
        } // .onReceive
    } // body
    func startPlayAndTimer() {
        // 多重でタイマーを開始しないようにする
        stopSelectedTimer()
        // 終了時刻は、残り時間を考慮
        endTime = Date().addingTimeInterval(remainingTime)
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
        // remainingTimeが0よりも小さく、endTimeが存在しなければ処理しない
        guard remainingTime > 0, let endTime else {
            return
        }
        selectedDurationMinutes = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // 現在時刻
            let now = Date()
            // 現在時刻と終了時刻の差を評価し、0以上の値を返す
            remainingTime = max(0, endTime.timeIntervalSince(now))
            print(remainingTime)
            // remainingTimeが0以下のとき
            if remainingTime <= 0 {
                // タイマーが終了したらタイマーとfadeOutTimerを停止
                stopSelectedTimer()
            }
        }// selectedTimer
    } // startTimer
    // func stopTimer
    func stopSelectedTimer() {
        // selectedTimerを無効化
        selectedDurationMinutes?.invalidate()
        // selectedTimerをnil
        selectedDurationMinutes = nil
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
    func updateState(newState: PlaybackState) {
        // newStateが以下の状態となる場合
        switch newState {
            // 再生状態になったら
        case .playing:
            // startPlayAndTimerを実行
            startPlayAndTimer()
        case .stopped:
            // 曲を停止
            audioPlayer?.pause()
            // 30秒を入れ直す
            fadeOutTime = 30.0
            // playerをnilに
            audioPlayer = nil
            // タイマー停止
            stopSelectedTimer()
            // fadeOutEndTimerを無効、nilにする
            stopFadeOutEndTimer()
        case .paused:
            // 曲を一時停止
            audioPlayer?.pause()
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
    } // fetchPreviewURL
    // 曲を再生するメソッド
    private func playBack() {
        // previewURL、fadeOutEndTimeが存在しなかったら
        guard let previewURL,
              let fadeOutEndTime else {
            print("previewURLが存在しません")
            // 処理終了
            return
        } //guard let
        // playerがnilのとき（初めての再生のとき）
        if audioPlayer == nil {
            print("🙆新しいプレーヤーを取得しました！")
            // playerにpreviewUrlを代入する
            audioPlayer = AVPlayer(url: previewURL)
            // ボリュームを0に設定
            audioPlayer?.volume = 0.0
            // 再生する
            audioPlayer?.play()
            print("🍀プレイヤーの状態は\(String(describing: audioPlayer?.status.rawValue))")
            print("📣ボリュームは\(String(describing: audioPlayer?.volume))")
            // フェードイン
            fadeIn(player: audioPlayer!, duration: 5)
        } else {
            // 再開したとき
            print("🌸一時停止した後の再開だよ！")
            // 再生するのみ
            audioPlayer?.play()
        } // if player
        // 多重にfadeOutEndTimerが実行されないようにする
        stopFadeOutEndTimer()
        // フェードアウトする時間を管理するタイマー
        fadeOutEndTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // 現在時刻
            let now = Date()
            // fadeOutTimeはfadeOutEndTimeに向かって0.1秒スライスする　0と比較し、大きい値を格納
            fadeOutTime = max(0, fadeOutEndTime.timeIntervalSince(now))
            print("❤️フェードアウトのタイマーは\(fadeOutTime)")
            // fadeOutEndTimeの5秒前になったら
            if fadeOutTime >= 5 && fadeOutTime < 5.1 {
                // 5秒かけてフェードアウト
                fadeOut(player: audioPlayer!, duration: 5.0)
            } else if fadeOutTime > 0 && fadeOutTime < 5 {
                // 0 < fadeOutTime < 5 のとき
                print(fadeOutTime)
                // 残り時間をかけてフェードアウト
                fadeOut(player: audioPlayer!, duration: fadeOutTime)
            } else if fadeOutTime == 0 {
                // fadeOutTimeが0のとき
                // 処理なし
                return
            } // if fadeOutTime...
        } // fadeOutEndTimer
        print("⭐️previewURLはこちら\(previewURL)")
    } // func playBack()
    // 自然に聞こえるフェードイン
    func fadeIn(player: AVPlayer, duration: TimeInterval) {
        // もしisFadeOutがtrueまたはremainingTimeが10秒以下なら
        if isFadeIn || isFadeOut || remainingTime <= 10 {
            // フェードインしない
            return
        } // if isFadeIn
        // isFadeInをtrueに
        isFadeIn = true
        // 100ミリ秒ごとに音量を変更
        let interval: TimeInterval = 0.1
        // 合計ステップ（フェードインをする時間が5なら、intervalが0.1なので段階は50）
        let totalSteps = Int(duration / interval)
        // 現在のステップ　初期は0
        var currentStep = 0
        // フェードインのタイマー
        fadeInTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            // 現在の段階が合計段階よりも小さいとき
            if currentStep < totalSteps {
                // 音量の変更を指数関数的に調整
                let normalizedTime = Double(currentStep) / Double(totalSteps)
                // 2乗することで、初期はゆっくり、後半は急激に上昇
                player.volume = Float(pow(normalizedTime, 2))
                // 現在のステップ　初期は0
                currentStep += 1
            } else {
                // 最大音量に設定
                player.volume = 1.0
                // fadeInTimerを無効に
                fadeInTimer?.invalidate()
                // fadeInTimerをnilに
                fadeInTimer = nil
                // isFadeInをfalseに
                isFadeIn = false
            } // if currentStep < totalSteps
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
        // isFadeOutをtrueに
        isFadeOut = true
        // フェードアウトは0.1刻み
        let interval: TimeInterval = 0.1
        // 合計ステップ（フェードアウトをする時間が5なら、intervalが0.1なので段階は50）
        let totalSteps = Int(duration / interval)
        // 現在のステップ　初期は0
        var currentStep = 0
        // 現在の音量を開始音量とする
        let startVolume = player.volume
        // フェードアウトのタイマー　インターバルは0.1、繰り返す
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            // 現在の段階が合計段階よりも小さいとき
            if currentStep < totalSteps {
                // 音量の変更を指数関数的に調整
                let normalizedTime = Double(currentStep) / Double(totalSteps)
                // 音量が徐々に減少
                player.volume = Float(startVolume * pow(Float(1.0 - normalizedTime), 2))
                // 現在の段階に1を足す
                currentStep += 1
            } else {
                // 音量をゼロに設定
                player.volume = 0.0
                // プレイヤーを止める
                player.pause()
                // プレイヤーをnilに
                self.audioPlayer = nil
                // タイマーを無効に
                fadeOutTimer?.invalidate()
                // fadeOutTimerをnilに
                fadeOutTimer = nil
                // フェードアウトが終わったら通知を送信
                NotificationCenter.default.post(name: fadeOutNotification, object: nil)
            } // if currentStep
        } // Timer
    } // func fadeOut
} // ContentView


#Preview {
    ContentView()
}

