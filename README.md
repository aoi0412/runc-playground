# runc ハンズオン

Ubuntu 26.04 に公式パッケージの `runc`、`busybox-static`、`vim` を導入し、
`/root/runc-hands-on` に OCI bundle（`rootfs` と `config.json`）を用意します。
ARM64 / AMD64 はビルド環境に応じて選択されます。
Ubuntu のタグを固定していますが、パッケージはビルド時点のリポジトリから取得します。

## ビルド・起動（Mac側）

この Dockerfile のあるディレクトリで実行します。
現在の Alacritty が Ubuntu の中なら、別のターミナルで Mac 側から実行してください。

```bash
docker build -t runc-hands-on .
docker run --privileged -it --name runc-hands-on runc-hands-on
```

`--privileged` は内側で namespace や mount を作るための起動時設定です。
Dockerfile では指定できません。この環境はローカル学習用として使用してください。
既存の `runc-dev` とは別のコンテナ名なので、既存環境も残ります。

## 対話操作（Ubuntu側）

```bash
runc --version
cat config.json
runc run mycontainer
```

内側の BusyBox シェルで実行します。

```sh
hostname
ps
ls /
id
exit
```

`ps` では `sh` が PID 1 として見えます。
`exit` で Ubuntu 側に戻り、`runc run` のコンテナ管理情報も片付けられます。

## 作成・起動・停止を分ける（Ubuntu側）

```bash
cp config.sleep.json config.json
runc create mycontainer
runc list
# STATUS: created

runc start mycontainer
runc list
# STATUS: running

runc exec mycontainer ps
runc state mycontainer

runc kill mycontainer KILL
runc list
# STATUS: stopped（反映まで少し時間がかかる場合は再実行）

runc delete mycontainer
runc list
```

300秒経つと `sleep` が自然終了します。その場合は `kill` を省略して `delete` します。
対話用に戻すには `cp config.interactive.json config.json` を実行します。

## 再開（Mac側）

Ubuntu 側で `exit` して停止した場合：

```bash
docker start -ai runc-hands-on
```

起動中の Ubuntu に別のシェルから接続する場合：

```bash
docker exec -it runc-hands-on bash
```

Dockerfile に記述した初期環境は再ビルドできます。
ハンズオン中の変更はコンテナ内に保存されますが、コンテナを削除すると失われます。

参考：
- https://github.com/opencontainers/runc
- https://zenn.dev/k_yoshi/articles/7e1b80b874af4c
