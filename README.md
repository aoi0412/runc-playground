# runc / containerd ハンズオン

Ubuntu 26.04 に公式パッケージの `runc`、`busybox-static`、`vim`、`containerd`（`ctr` を含む）を導入し、
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

## containerd を操作する（Ubuntu側）

イメージから起動すると containerd が自動起動します。systemd は使用しません。
ログは `/var/log/containerd.log`、データは `/var/lib/containerd` です。
起動時に Ubuntu 側のプロセスを子 cgroup へ移し、内側のランタイム用のコントローラーを有効にします。
`ctr` はこの Ubuntu 内の containerd に接続します。
Mac の Docker が管理するコンテナは表示されません。

```bash
export CONTAINERD_SNAPSHOTTER=native
ctr version
ctr plugins ls
ctr images pull --local docker.io/library/busybox:latest
ctr images ls
ctr run --rm -t docker.io/library/busybox:latest ctr-shell sh
```

BusyBox 内で `ps`、`ls /`、`exit` を試せます。
Docker 内での overlayfs の重ね合わせを避けるため、`native` snapshotter を使います。
新しいイメージにはこの環境変数を設定済みです。
取得時の `--local` は、ctr 側で native snapshotter への展開を行う指定です。
containerd 2.2 の既定の転送サービス設定では native への展開が失敗するため指定します。
次はバックグラウンドで動かし、コンテナの登録情報と実行中のタスクを比較します。

```bash
ctr run -d docker.io/library/busybox:latest ctr-demo sleep 300
ctr containers ls
ctr tasks ls
ctr tasks exec --exec-id inspect ctr-demo ps
ctr tasks kill --signal SIGKILL ctr-demo
# STATUS が STOPPED になったことを確認（まだなら再実行）
ctr tasks ls
ctr tasks delete ctr-demo
ctr containers delete ctr-demo
```

`containers` は設定などの登録情報、`tasks` は実際の実行状態を扱います。
`runc list` と `ctr containers ls` は別の管理情報を参照します。
この手順では CNI によるネットワーク設定は行っていないため、内側からの外部通信は設定していません。

既存のコンテナはイメージを再ビルドしても更新されません。
既存環境に手動導入する場合は、このリポジトリの `start-containerd.sh` を Ubuntu 内にコピーしてから以下を実行します。

```bash
apt-get update
apt-get install -y containerd ca-certificates
install -m 755 start-containerd.sh /usr/local/bin/start-containerd
start-containerd
```

今回更新した既存環境には `start-containerd` も配置しています。
その環境を `docker start -ai` で再開したときは、Ubuntu 側で `start-containerd` を実行してください。
新しいイメージから起動した環境では、通常この手動起動は不要です。

参考：
- https://github.com/opencontainers/runc
- https://github.com/containerd/containerd/blob/main/docs/getting-started.md
- https://zenn.dev/k_yoshi/articles/7e1b80b874af4c
