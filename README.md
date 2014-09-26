IRKit GUI
=========

![screenshot](screenshot.png)

## 仕組み

#### IRKit GUI (Sinatra) --> RubyGem`irkit` / `$ irkit` --> IRKit 本体

> [気づいたら IRKit GUI つくってた - X X X](http://syonx.hatenablog.com/entry/2014/08/12/011046)

## インストール

recommended: `bundler`, `foreman`

```bash
$ git clone https://github.com/syon/irkit-gui.git
$ cd irkit-gui
$ bundle install --path vendor/bundle
$ foreman start
```

- ブラウザでサーバにアクセスすると、上記のような画面が表示される
- 上記の例、サーバ自身のブラウザの場合は http://localhost:5000
- iPhone など他のデバイスからアクセスする場合は IP を指定するなど
    - Mac だと`$ ifconfig | grep "inet "`で表示される`192.168.0.123`とか

## 使い方

### ボタンを追加する
0. IRKit 本体にリモコン信号を記憶させる
0. GUI の "Enter new name" のところに好きな名前を入力して Enter

### 赤外線信号を発信する
- ボタンを押す

### ボタンを削除する
コマンドからどうぞ。
```bash
$ bundle exec irkit --delete "the name"
```

### 設定
__.env__ ファイルのサンプル
```bash
USE_BUNDLER=no
IRKIT_ADDRESS=192.168.0.16
IRKIT_DATA_FILE=/path/to/.irkit.json
```
- __USE_BUNDLER__
    - (default): `yes`
    - `no`: 内部で呼び出している`$ bundle exec irkit`を`$ irkit`にする
- __IRKIT_ADDRESS__
    - IRKit に IP アドレス指定で接続する
        - Bonjour が不安定なときなど
- __IRKIT_DATA_FILE__
    - 登録した赤外線信号のデータファイルのありか
        - RubyGem "irkit" が管理している
        - デフォルトはホームの下
