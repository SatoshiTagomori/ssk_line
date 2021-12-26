# ssk_line
このGemはRuby on RailsでLineログインを簡単にするためのものです。
Lineでログインしてもらい、登録してもらった人に何かを教える、というニッチな商売に最適化しているため、テーブルの構造まで踏み込んでおります。
その分、そのルールに沿っている以上、実装が楽です。


# 環境変数の設定
環境変数に以下の内容を設定しておく。

- LINEAPI_CHANNEL_ID
- LINEAPI_CALLBACK_URL
- LINEAPI_CHANNEL_SECRET

これらの仔細はLINE Login APIのコンソール画面から情報を取得できる。

# ユーザーテーブルの作成
テーブル名（モデル名）は何でも良いです。
その代わり、下記のカラムが必要になります。
- :teacher => boolean(trueの場合は講師アカウントとみなす）
- :admin => boolean（trueの場合は管理者アカウントとみなす）
- :lineid => string（lineのidが入る）
- :dname => string(lineの表示名が入る）
- :picture =>string（lineの画像URLが入る）


# Railsでの使用について
Gemfileに  
`gem 'ssk_line'`  
を書いておいてbundle installするのは前提として、

実際に使うのは２つのメソッドだけです。

## SskLine.login_url(request)
引数としてrequestを入れておきます。そのまま書けば、OKです  
`<%= link_to 'lineでログイン' ,SskLine.login_url(request) %>`  
という感じです。  
ログイン用のURLを取得するだけでなく、セッションにCSRFトークンも入れておきます。

## SskLine.line_login_process(request,controller,user_model_class)
リダイレクト先のアクションで使います。
コントローラー内で使うと思いますので、
```SskLine.line_login_process(request,self,User)```  
というような書き方になるかと思います。

中で何をやっているかというと、
- 環境変数などちゃんと設定されているかの確認
- CSRFトークンのチェック
- トークンが合っていればアクセストークンの取得
- アクセストークンが取得できたらプロフィールの取得
- そのプロフィールのlineidがすでにusersテーブルに存在すれば表示名と画像のURLを上書き
- そのプロフィールのlineidが存在しなければ新しく作成。
- 新規作成する際に一人目のユーザーであれば強制的に管理者権限にする
という感じです。

１個でもエラーがあればroot_pathに強制的に飛ばします。そのため  
`if SskLine.line_login_process(request,self,User) == false then return end`  
こんな１行を入れておけば良いです。


