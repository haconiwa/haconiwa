## Guidance scope

This contribution guide is applied to all of projects under the `haconiwa` organization.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/haconiwa/haconiwa. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Information which are nice to be written at issues

(As you know) You can get haconiwa's version via `haconiwa version`.

Also, bundled mruby gems' and mruby itself's versions via `haconiwa revisions`.

```console
$ haconiwa revisions
mgem and mruby revisions:
--------
MRUBY_CORE_REVISION     3c1078376918c8b8d30b86585655c343dfb3ad16
mruby-argtable          8c9b530ebdc73776a870b2d9870d947c413b5299
mruby-capability        f5e3359fbe2cc121250155794f0b122fa1d79d90
mruby-cgroup            8061fa362f91c7dcbfb9b7c1cf2624b0d0c9ab6b
mruby-cgroupv2          e73faa0b126b5788bd6a4ffaa630c50550d143ff
mruby-dir               14bc5c3e51eac16ebc9075b7b62132a0cf5ae724
mruby-env               57f0d737a4ece49dc5b6f1c7ee09b0bc8f8adf87
mruby-exec              105e302d147c458e4bd60d43abc1a0aa703969d5
mruby-forwardable       f3728d96ef25bb038f113863cc30195d44a41d35
mruby-io                728d313b2c238ac0f41a4aa7e4a88e6a8fee8079
mruby-linux-namespace   f3bfca41ce5fd05b7d5aa642433eb8779c388b07
mruby-localmemcache     3e35ae58cb69fdfd382d1d7d19ff10cd44be55ba
mruby-mount             7b56955e3f82925c7e5d45b6c8f3dabf8d3ca3e5
mruby-onig-regexp       170aecd88f6ee49ae9a5632735591ebd38993943
mruby-pack              7e014efe45ac7c8f5a0418b6f180634d33e0a9dd
mruby-process           074a1e0bd93af38f33183351f171e2e4c1ec2e83
mruby-process-sys       bf1a23c8c321bb350d9967b52c6d03d0fe1b6d9b
mruby-procutil          4ff5ea435277125f974d8f5dde6d9edf689a1fcd
mruby-resource          421fbbd5148cbcfe56ba3408165e1331791c5e05
mruby-seccomp           ee0e09f0648241dcaec7a2c06fc25afe67f526e0
mruby-shellwords        2a284d99b2121615e43d6accdb0e4cde1868a0d8
mruby-signal-thread     2e35d628f229e2b69794137028ef9728bba9cd47
mruby-sleep             da9e1dfa7aaee32f53fba884584dc36157b05f60
mruby-socket            3dad125a1cd93e70a1762e9c6a1d5e01554ad71c
mruby-syslog            aa7794b2800b30e9b3f8a32db8e3f1a6824f3de4
mruby-thread            2c51fe9dc06bd1c82479a982beab586cea29eadb
mruby-timer-thread      2e22f558656707b3adcfcc9038374961ac52fb4c
mruby-uname             422f61705a1232f8d033ace3945826ea6b0421a8
```

Also, current haconiwa packages are flagged `enable_debug`, so you can get raw error backtraces in mruby lauyer.

With `haconiwa run -T` option, you can force to set the container process in front of terminal, and then the process's detailed error log(stdout/stderr) are visible.

System informations listed below are also welcomed.

* Kernel version (`uname -a` result)
* Linux distributions (CenotOS/Ubuntu/Debian/etc... , with version)
* CPU archtecture (...but x86_64 is an only expected arch)

## Loose-tie policy

We always want to wear a "loose tie", so this contributing guide is only a guide at all, but we wish you OSS programmers to have respect for others every time you code.

## 日本語でのPull Request/Issueについて (Guidance for people that speak Japanese but are a little poor at English)

The main maintainer @udzura is Japanese native speaker, so your Japanese issues/pull request descriptions are interpreted!

日本語でのPull Request/Issueの作成には問題はありませんが、非日本語話者の便利のために幾つかの制限や、対応をする場合があります（例えばロシア語話者の作ったとあるプロジェクトのPRやIssueが、全てロシア語で書かれていた時の、あなたの気持ちを考えてみていただけると幸甚です）。

* タイトルや本文等を、原文がそれと分かる状態で、英語に意訳する場合があります。
* コメントなど成果物本体に日本語が含まれる場合には修正をお願いします。難しい場合には当該PRでご相談ください。
* `haconiwa/book` プロジェクトに関しては自然言語が中心のプロジェクトで、翻訳のコストが大きいと判断して例外とします。すべて日本語でIssueやドキュメント等を書いていただいて構いません。

本ドキュメント原作者 @udzura の個人的には（こんなことをOSSのCONTRIBUTINGに書くのはなんなのか、とも思いますが）、私も日本語母語話者ですので、日本語で技術の情報を得て、日本語で技術について考える権利は大事にすべきだと考えています。一方で、純粋に便利のためであったり、非日本語話者の心理的安全性のための工夫も許容していただくことを望みます。
