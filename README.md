# axs　- UNIX哲学を守ったつもりのsimpleなawsコマンド
A simple 'aws' command 'axs' written in POSIX sh. axs(access) to aws(amazon web services) with posixism.
このコマンドは、AmazonWebServicesにアクセスし、数々のwebサービスを利用したり、アプリを構築したりするために作られた、
POSIX原理主義に基づく、なんちゃってawsコマンドです。

## AWS APIツールは「いつでも、どこでも、すぐ」使えるわけではない。
作った経緯1です。バージョン依存や環境依存の大きい、AWS APIツールはいつでもどこでもすぐに使えるわけではありません。
また、SDKやCLIもそれらをインストールできない環境だと、役に立ちません。意外なこと使えない環境を目にする機会も多いです。

しかしながら、環境やバージョンアップに悩まされずにAWSのサービスを利用したい、というニーズも時にはあるのではないでしょうか？
浅くネットサーフィンした限りでは、そのように認識しています。

これは、そのニーズに応えるために作りました。

POSIX shに準拠しているつもりなので、Windows, Mac, Linuxなどで、それこそコピーしてくるだけで「いつでも、どこでも、すぐ」動きます。

## 大量のオプション、引数からの解放
作った経緯２です。awsコマンドの大量の引数やオプション、サービスごとに異なる数々のサブコマンドにヘキヘキした覚えはありませんか？私はあります。
あれはUNIX哲学を守っていません。コマンドとクラウドへ渡すパラメーターがぐちゃぐちゃに混ざったシェルスクリプトを書くのはもうこりごりです。

このコマンドでは、その煩わしさから解放されます（嘘、かもしれません）UNIX哲学を守ったつもりです。また、
RESTfulの概念も大事にしているので直感的な操作が可能かもしれないです。

## 使い方
ダウンロードしたら、このリポジトリのaxs/binにPATHを通してください。
### 1. 基本
使い方は簡単です。設定ファイル（書き方は後述）を読み込むだけです。

例えば、catコマンドを使って
```
$cat config_file | axs
```
または、引数に設定ファイルを置くだけです
```
$axs config_file
```

### 2. 設定ファイルのデータ形式について
AWSはREST APIを用いています。そこで、今回は、正しいのかどうかは横に置いておいて、HTTPにちなんだデータ形式の設定ファイルを記述します。

以下のような形式をとることにしました。
```
METHOD URI    (リクエストライン)
Key Value
key Value
Key Value     (キーバリュー形式に分解したクエリ)
Host: ec2.ap-northeast-1.amazonaws.com (必須ヘッダー)
Content-Type: application/hoghoge (場合によっては必須のヘッダー)
X-Amz-moge: hogehogehoge (追加のヘッダー)

body 部(コンテンツの中身)
xmlとかjsonとかバイナリデータ
```
基本的に、Host,Content-Typeヘッダのみが必須だと考えてもらっていいです。


AWS APIを利用するので、body部には基本的にxmlやjsonを記述します。ただし、S3, Polly, Rekognitionなどを利用する時にはバイナリデータを
アップロードしなければならない時があります。また、xml,jsonが長く煩雑な時は、リクエストライン、クエリ、ヘッダ部とbody部を分離したいと思う時もあるでしょう。

そのような時に、axsコマンドの-fオプションを使います。
### 3. -fオプション
body部を分離して別ファイル（body.txtなど）にしてaxsコマンドを使う場合には以下のようにします。
```
$cat<<END | axs -f moon.jpg
PUT /image.jpg
Host: Bucket.s3.amazonaws.com (東京リージョンの場合はbucket.s3-ap-northeast-1.amazonaws.com)
Content-Type: image/jpeg
END
```
*この例では、ローカルのmoon.jpgという画像ファイルをs3のBucketバケットにimage.jpgという名前で保存しています。
### 4. -qオプション
これはAPIアクセス後に返ってくる、レスポンスのレスポンスヘッダーを表示するかしないかを決定するオプションです。
デフォルトではレスポンスヘッダを表示します。AWSのREST APIがヘッダ情報をよく扱うので、汎用性を高めるためにそうのようにしてあります。

例えば、以下のような違いになります。
```
$cat <<END | axs 
GET /
Action DescribeVpcs
Version 2016-11-15
Host: ec2.ap-norteast-1.amazonaws.com
Content-Type: application/x-www-form-urlencoded
END

HTTP 200  OK
hogehogehoe
hogehogehoge
hogehogレスポンスヘッダー

<xml ......>
```
-qオプションを利用した、レスポンスヘッダなしの場合はxmlやjsonやバイナリが直に帰ってきますので、パイプでつないで加工したりするのに便利です。
```
（pollyに喋ってもらう）
cat config_file | axs -q > polly.mp3

（xmlが返ってくる）
cat config_file | axs -q | parsrx.sh(POSIX原理主義製xmlパーサー)

（jsonが返ってくる）
cat config_file | axs -q | parsrj.sh(POSIX原理主義製jsonパーサー)
```

## Requisites
- openssl ver1.0.0以上
- utconv (同梱、秘密結社シェルショッカー日本支部)
- urlencode (同梱、秘密結社シェルショッカー日本支部)
- cat
- awk
- sed
- printf
- echo
- grep
- curl
- wget


## TIPS
- 設定ファイルの書き方は、AWS API referenceなどを参照してください。設定ファイルの記述はクエリ部分以外はHTTPと同じです。
深く悩まずに記述できることでしょう。

- Content-Lengthヘッダ,x-amz-content-shaナンチャラヘッダ,Autorizationヘッダは自動生成されるので、考慮する必要はありません。

- 私も仲間に加えてもらった秘密結社シェルショッカー日本支部のPOSIX原理主義製の他コマンドと相性がいいです。
これを機に秘密結社シェルショッカー日本支部よりダウンロードしてくることをお勧めします。
中でもmojihameコマンドとの相性は抜群です。https://github.com/ShellShoccar-jpn/installer

### TIPS 例えば、クエリAPIとmojihameコマンド
テンプレのようい、template
```
GET /
QUERY
%1 %2
QUERY
Version 2016-11-15
Host: ec2.ap-northeast-1.amazonaws.com
Content-Type: application/x-www-form-urlencoded
```

設定の用意、config.txt
```
Action Hogehoge
AAAAA dededed
hogemoge ahahaha
```

いざアクセス
```
cat config.txt | mojihame -lQUERY template - | axs -q | parsrx.sh | 加工
```


素晴らしいparsrsのコマンドを用いれば、無駄に多くのコマンドを用いずにレスポンスの解析もできます

ちなみに
```
cat config.txt | mojihame -lQUERY template -
```
までの結果だけ抜き出すと以下のようになっています。
```
GET /
Action Hogehoge
AAAAA dededed
hogemoge ahahaha
Version 2016-11-15
Host: ec2.ap-northeast-1.amazonaws.com
Content-Type: application/x-www-form-urlencoded
```

## 感想
意味がるのか知りません。あるかもしれないし、ないかもしれません。ただ楽しかったですとだけ付け加えておきます。
