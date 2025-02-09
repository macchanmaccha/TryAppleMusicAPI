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
    // 状態を管理する列挙体
    enum Status {
        // 再生中
        case playing
        // 停止
        case stopped
        // 一時停止
        case paused
    }
    // タイマーの状態　初期は.stopped
    @State private var state: Status = .stopped
    /// プレビューURL
    @State private var previewURL: URL?
    /// 再生状態
    @State private var isPlaying = false
    /// プレイヤー
    @State private var player: AVPlayer?
    // ロード状態を管理する変数
    @State private var isLoading = false
    // 通知の名前
    let notificationName = Notification.Name("notificationName")
    // 初期値を1分とする
    @State private var selectedTime: Int = 1
    // ユーザーが選択する時間のタイマー
    @State private var selectedTimer: Timer?
    // ユーザーが選択する時間のタイマーの終了時刻
    @State private var endTime: Date?
    // 音再生のタイマー
    @State private var soundTimer: Timer?
    // 表示秒数(タイマーの時間)
    @State private var displayTime: TimeInterval = 0
    // スタート時間
    @State private var startTime: Date?
    // 一時停止時の経過時間
    @State private var elapsedTime: TimeInterval = 0
    // 残り時間
    @State private var remainingTime: TimeInterval = 0
    // fadeOutを管理
    @State private var isFadeOut = false
    // fadeInのタイマー
    @State private var fadeInTimer: Timer?
    // fadeOutのタイマー
    @State private var fadeOutTimer: Timer?
    // fadeOutを修了するタイマー
    @State private var fadeOutEndTimer: Timer?
    //    <iframe allow="autoplay *; encrypted-media *;" frameborder="0" height="150" style="width:100%;max-width:660px;overflow:hidden;background:transparent;" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation" src="https://embed.music.apple.com/jp/album/%E7%B2%95%E6%AF%9B%E5%B7%9D-%E3%81%9B%E3%81%9B%E3%82%89%E3%81%8E/259872642?i=259872743"></iframe>
    // 設定画面へ誘導するアラート
    @State private var isShowAlert = false
    private let iD: String = "259872743"
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
                        startPlayAndTimer()
                        isPlaying = true
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
                // ボタンを表示
                Button(action: {
                    updateState(newState: .paused)
                    pauseTimer()
                }) {
                    // isPlayingがtrueのときは停止、falseのときは再生を表示
                    Text("一時停止")
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                // ボタンを表示
                Button(action: {
                    updateState(newState: .playing)
                }) {
                    // isPlayingがtrueのときは停止、falseのときは再生を表示
                    Text("再開")
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
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
                //                }
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
            stopTimer()
            displayTime = Double(selectedTime * 60)
        } // .onAppear
        .onChange(of: selectedTime) {
            displayTime = Double(selectedTime * 60)
        } // .onChange
        // 再生完了（音量0）の通知を受け取る
        .onReceive(NotificationCenter.default.publisher(for: notificationName)) { _ in
            isPlaying = false
            print("音量が0になりました。再度再生をします")
            // elapsedTimeが0秒になったら、秒数をselectedTime＊60にする
            if displayTime == 0 {
                displayTime = Double(selectedTime * 60)
            }
            // endTimeが存在し、endTimeが過去だったら
            if let endTime = endTime, Date() >= endTime {
            } else {
                // タイマー終了5秒前の間にplayPreviewを実行しないようにする処理
                // isFadeOutがtrueなら
                if isFadeOut == true {
                    return
                    // それ以外なら
                } else {
                    // 音量が0になったら再生
                    playBack()
                }
            } // if let endTime...
        } // .onReceive
    } // body
    func startPlayAndTimer() {
        // 終了時刻を計算
        endTime = Date(timeInterval: TimeInterval(selectedTime * 60), since: Date())
        // 再生を開始
        playBack()
        // タイマーを開始
        startTimer()
        print("タイマーは\(endTime!)で終わり")
    }
    
    func startTimer() {
        // 多重でタイマーを開始しないようにする
        stopTimer()
        // displayTimeが0よりも小さければ処理しない
        guard displayTime > 0 else {
            return
        }
        isPlaying = true
        // 現在の基準
        let now = Date()
        // 終了時刻は、残り時間を考慮
        endTime = now.addingTimeInterval(displayTime)
        print("終了時刻を計算すると\(endTime)")
        if let endTime = endTime {
            selectedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                // 現在時刻
                let now = Date()
                // 現在時刻と終了時刻の差を評価し、0以上の値を返す
                displayTime = max(0, endTime.timeIntervalSince(now))
                print(endTime.timeIntervalSince(now))
                print(displayTime)
                // displayTimeが0以下のとき
                if displayTime <= 0 {
                    // タイマーが終了したら再生を停止
                    stopTimer()
                }
//                // フェードアウト
//                if let player = player {
//                    fadeOut(player: player, duration: 5.0)
//                } else {
//                    print("プレイヤーがnilです")
//                } // if let player
            }// selectedTimer
        } // if let
        // 0.1秒ずつ刻む
        
    } // startTimer
    // func pauseTimer
    func pauseTimer() {
        isPlaying = false
        selectedTimer?.invalidate()
        selectedTimer = nil
    } // pauseTimer
    // func stopTimer
    func stopTimer() {
        selectedTimer?.invalidate()
        selectedTimer = nil
    } // stopTimer
    // 状態更新
    func updateState(newState: Status) {
        // newStateが以下の状態となる場合
        switch newState {
            // 再生状態になったら
        case .playing:
            // 曲を再生する
            player?.play()
            // タイマーを再開する
            startTimer()
        case .stopped:
            // 曲を停止
            player?.pause()
            // playerをnilに
            player = nil
            // タイマー停止
            stopTimer()
            // タイマー表示
            displayTime = Double(selectedTime * 60)
        case .paused:
            // 曲を一時停止
            player?.pause()
            // ストップ
            stopTimer()
            // タイマーを一時停止
            selectedTimer?.invalidate()
            // タイマーをnilに
            selectedTimer = nil
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
              let endTime = endTime else {
            // プレビューURLが存在しなかったらコメント
            print("previewURLが存在しません")
            return
        }
        // playerにpreviewUrlを代入する
        player = AVPlayer(url: previewURL)
        // 再生する
        player?.play()
        // isPlayingをtrueにする
        isPlaying = true
        // フェードイン
        fadeIn(player: player!, duration: 5)
        // フェードアウト
        // endTimeから5秒前は必ずフェードアウト
        if Date() >= endTime - 5 {
            fadeOut(player: player!, duration: 5.0)
        } else {
            fadeOutEndTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: false) { _ in
                // 5秒かけてフェードアウト
                fadeOut(player: player!, duration: 5.0)
            }
        }
        print("⭐️previewURLはこちら\(previewURL)")
    } // func playBack()
    // 自然に聞こえるフェードイン
    func fadeIn(player: AVPlayer, duration: TimeInterval) {
        // もしisFadeOutがtrueになったら
        if isFadeOut {
            // フェードインしない
            return
        }
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
            }
        }
    }
    // 自然に聞こえるフェードアウト
    func fadeOut(player: AVPlayer, duration: TimeInterval) {
        print("🧡fadeOut関数をたたいたよ！")
        // フェードアウトしているとき
        if isFadeOut == true {
            // 何も処理しない
            return
        } // if isFadeOut...
        isFadeOut = true
        let fadeDuration = duration
        let interval: TimeInterval = 0.1
        let totalSteps = Int(fadeDuration / interval)
        var currentStep = 0
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if currentStep < totalSteps {
                // 音量の変更を指数関数的に調整
                let normalizedTime = Double(currentStep) / Double(totalSteps)
                // フェードインとは逆に音量が徐々に減少
                player.volume = Float(pow(1.0 - normalizedTime, 2))
                currentStep += 1
            } else {
                // 音量をゼロに設定
                player.volume = 0.0
                player.pause()
                timer.invalidate()
                isFadeOut = false
                // 音量が0になったら通知を送信
                NotificationCenter.default.post(name: notificationName, object: nil)
            } // if currentStep
        } // Timer
    } // func fadeOut
    
} // ContentView


#Preview {
    ContentView()
}

