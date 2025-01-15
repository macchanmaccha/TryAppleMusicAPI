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
    //
    @State private var elapsedTime: Double = 0
    // fadeOutを管理
    @State private var isFadeOut = false
    // fadeInのタイマー
    @State private var fadeInTimer: Timer?
    // fadeOutのタイマー
    @State private var fadeOutTimer: Timer?
    // fadeOutを修了するタイマー
    @State private var fadeOutEndTimer: Timer?
    //<iframe allow="autoplay *; encrypted-media *;" frameborder="0" height="150" style="width:100%;max-width:660px;overflow:hidden;background:transparent;" sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation" src="https://embed.music.apple.com/jp/album/%E9%8A%80%E6%B2%B3%E9%89%84%E9%81%93999/477643015?i=477643022"></iframe>
    // 設定画面へ誘導するアラート
    @State private var isShowAlert = false
    private let iD: String = "477643022"
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
                Text("\(Int(elapsedTime))秒")
                // プレビューURLがnilでない場合
                if previewURL != nil {
                    // ボタンを表示
                    Button(action: {
                        // 再生
                        startPlayAndTimer()
                    }) {
                        // isPlayingがtrueのときは停止、falseのときは再生を表示
                        Text(isPlaying ? "停止" : "再生")
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(isPlaying ? Color.red : Color.blue)
                            .cornerRadius(10)
                    }
                    // それ以外
                } else {
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
                }
            } // if isLoading
        } // VStack
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
                    )
                }
        .onAppear {
            stopTimer()
            elapsedTime = Double(selectedTime * 60)
            print("はじまるよ！")
        } // .onAppear
        .onChange(of: selectedTime) {
            elapsedTime = Double(selectedTime * 60)
        } // .onChange
        // 再生完了（音量0）の通知を受け取る
        .onReceive(NotificationCenter.default.publisher(for: notificationName)) { _ in
            print("音量が0になりました。再度再生をします")
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
                    togglePlayback()
                }
            } // if let endTime...
        } // .onReceive
    } // body
    func startPlayAndTimer() {
        // 終了時刻を計算
        endTime = Date(timeInterval: TimeInterval(selectedTime * 60), since: Date())
        // 再生を開始
        togglePlayback()
        // タイマーを開始
        startTimer()
        print("タイマーは\(endTime!)で終わり")
    }
    
    func startTimer() {
        // 多重でタイマーを開始しないようにする
        stopTimer()
        // 状態の更新(playing状態にする)
        updateState(newState: .playing)
        // 0.1秒ずつ刻む
        selectedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            //            // 現在日時から終了時刻まで0.1秒ずつ引いていく
            if let endTime = endTime {
                elapsedTime = endTime.timeIntervalSince(Date())
            }
            print(elapsedTime)
            // endTimeが存在し、endTimeが過去だったら
            if let endTime = endTime, Date() >= endTime  {
                print("endTimeは過去です")
                // タイマーが終了したら再生を停止
                stopTimer()
                // フェードアウト
                if let player = player {
                    fadeOut(player: player, duration: 5.0)
                } else {
                    print("プレイヤーがnilです")
                }
            }
        }// selectedTimer
        
    } // startTimer
    
    func stopTimer() {
        selectedTimer?.invalidate()
        selectedTimer = nil
    } // stopTimer
    
    // 状態更新
    func updateState(newState: Status) {
        if state == .playing && newState == .paused {
            player?.pause()
            stopTimer()
        } else if state == .paused && newState == .playing {
            player?.play()
            startTimer()
        }
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
            }
            // 楽曲IDを指定してリクエストを作成
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(trackID))
            // レスポンスを取得
            let response = try await request.response()
            // 曲とプレビューURLが存在する場合
            if let song = response.items.first,
               let previewURL = song.previewAssets?.first?.url {
                // previewURLに代入
                self.previewURL = previewURL
            } // if let
            // エラーの場合
        } catch {
            print("指定したトラックID（\(trackID)）の曲とpreviewURLがありません")
            print("エラーはこちら: \(error)")
            return
        }
    } // fetchPreciewURL
    // 曲を再生したり、停止したりするメソッド
    private func togglePlayback() {
        // previewURLが存在しなかったら何もしない
        guard let previewURL = previewURL else {
            // プレビューURLが存在しなかったらコメント
            print("previewURLが存在しません")
            return
        }
        print("⭐️previewURLはこちら\(previewURL)")
        // isPlayingがtrueなら
        if isPlaying {
            // ポーズにする
            player?.pause()
            // isPlayingをfalseにする
            isPlaying = false
            // true以外なら
        } else {
            // playerにpreviewUrlを代入する
            player = AVPlayer(url: previewURL)
            // 再生する
            player?.play()
            // isPlayingをtrueにする
            isPlaying = true
        }
    } // func togglePlayback()
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

