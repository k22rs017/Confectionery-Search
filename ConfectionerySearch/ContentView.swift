//
//  ContentView.swift
//  Confectionery Search
//
//  Created by Kazuma Uehara on 2024/12/04.
//

import SwiftUI
import SafariServices

//MARK: - Model
struct ApiResponse: Decodable { // JSONデータに対応した構造体
    let item: [Confectionery]
}

struct Confectionery: Decodable {
    let name: String?
    let url: String?
    let image: String?
}

//MARK: - ViewModel
class ConfectioneryViewModel: ObservableObject {
    @Published var confectioneries = [Confectionery]() // 表示するデータ
    @Published var isLoading = false // データ取得中かどうか
    @Published var searchText = "" // 検索文字列
    @Published var selectedURL: URL? // 選択したURL
    
    // 検索条件に応じたデータをフィルタリング
    var filteredConfectioneries: [Confectionery] {
        if searchText.isEmpty {
            return confectioneries
        } else {
            return confectioneries.filter { item in
                guard let name = item.name else { return false }
                return name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    // 選択されたアイテムのURLを検証し、選択状態を更新する関数
    func didSelectItem(item: Confectionery) {
        guard let urlString = item.url, let validURL = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        selectedURL = validURL
    }
    // データをAPIから取得する関数
    func fetchData() {
        let urlString = "https://sysbird.jp/toriko/api/?apikey=guest&format=json&order=r&max=100" // APIリクエスト
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            //            Task {
            //                updateUI(confectioneries: [], isLoading: false)
            //            }
            return
        }
        
        // ローディング開始
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decodedResponse = try JSONDecoder().decode(ApiResponse.self, from: data)
                let validItems = decodedResponse.item.filter { item in
                    guard let image = item.image, let name = item.name, let url = item.url else { return false }
                    return !image.isEmpty && !name.isEmpty && !url.isEmpty
                }
                await updateUI(confectioneries: validItems, isLoading: false)
            } catch let error as URLError {
                // ネットワーク関連のエラー
                print("Network error occurred: \(error.localizedDescription)")
                await updateUI(confectioneries: [], isLoading: false)
            } catch let error as DecodingError {
                // データのデコードエラー
                print("Failed to decode response: \(error.localizedDescription)")
                await updateUI(confectioneries: [], isLoading: false)
            } catch {
                // その他のエラー
                print("An unexpected error occurred: \(error.localizedDescription)")
                await updateUI(confectioneries: [], isLoading: false)
            }
        }
    }
    /// メインスレッドで UI を更新する関数
    @MainActor
    private func updateUI(confectioneries: [Confectionery], isLoading: Bool) {
        self.confectioneries = confectioneries
        self.isLoading = isLoading
    }
}

// MARK: - View
struct ContentView: View {
    @StateObject private var viewModel = ConfectioneryViewModel()
    @State private var showSafari = false // SafariViewを表示するフラグ
    
    var body: some View {
        NavigationStack {
            VStack {
                // 検索フィールド
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                        .padding(.leading, 8)
                    
                    TextField("Search for a confectionery", text: $viewModel.searchText)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 5)
                        .font(.system(size: 16))
                        .frame(height: 48)
                        .padding(.trailing, 8)
                        .disabled(viewModel.isLoading)  // ローディング中は無効化
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                // ローディング中の表示
                if viewModel.isLoading && viewModel.confectioneries.isEmpty {
                    VStack {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .padding(16)
                        Text("Fetching confectioneries...")
                            .foregroundStyle(.gray)
                    }
                    .frame(maxHeight: .infinity) // 空きスペースを埋める
                } else if viewModel.filteredConfectioneries.isEmpty {
                    // 検索結果がない場合
                    Text("No data available")
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity) // 空きスペースを埋める
                } else {
                    // リストの表示
                    List(viewModel.filteredConfectioneries, id: \.url) { item in
                        Button(action: {
                            viewModel.didSelectItem(item: item)
                            showSafari.toggle()
                        }) {
                            HStack {
                                // 画像URLがある場合は表示
                                if let imageUrl = item.image, let url = URL(string: imageUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 56, height: 56)
                                            .cornerRadius(12) // 角丸を追加
                                    } placeholder: {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    }
                                }
                                
                                VStack(alignment: .leading) {
                                    if let name = item.name {
                                        Text(name)
                                            .font(.headline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.black) // メインの色
                                    }
                                }
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 8) // アイテムの上下に余白を追加
                        }
                    }
                    //                    .frame(maxHeight: .infinity)
                    .refreshable {
                        //                            resetAndFetchData() // 再読み込み
                        viewModel.fetchData() // 再読み込み
                    }
                }
            }
            .onAppear(perform: viewModel.fetchData) // 初期データ取得
            .navigationTitle("Confectionery Search")
            .background(Color(UIColor.systemGroupedBackground)) // 背景色を調整
            .sheet(isPresented: $showSafari, content: {
                if let url = viewModel.selectedURL {
                    SafariView(url: url)
                }
            })
        }
    }
}

struct SafariView: View {
    let url: URL
    var body: some View {
        SafariViewController(url: url)
            .edgesIgnoringSafeArea(.all)
    }
}

struct SafariViewController: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    ContentView()
}
