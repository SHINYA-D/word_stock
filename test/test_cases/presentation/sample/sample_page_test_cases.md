## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/sample/sample_page.dart |
| 仕様書 | docs/detailed_design/presentation/sample/sample_page.md |
| クラス名 | SamplePage |
| テスト対象メソッド | build() / _showCreateDialog() / _showEditDialog() / _showDeleteDialog() / SampleListTile（メニュー） / FolderNameLengthFormatter |

対象は SamplePage 単体の描画・ユーザー操作（Widget テスト）。ViewModel（SampleViewModel）のロジック網羅は
`test/presentation/sample/sample_view_model_test.dart` が別に担当する（本項目書では扱わない）。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | 「A」の1件がある状態で画面を開いた場合、AppBar に「サンプル」と表示される [SMP-D01] | SMP-D01 #ff14e2 | 正常系 | build() | ✅ |
| 2 | 「A」の1件がある状態で画面を開いた場合、ボトムナビゲーションバーが表示され、「テスト」タブが選択状態になっている [SMP-D02] | SMP-D02 #76edfa | 正常系 | build() | ✅ |
| 3 | 「A」の1件がある状態で画面を開いた場合、画面の右下に FloatingActionButton が表示され、アイコンは Icons.add [SMP-D03] | SMP-D03 #cdb1f1 | 正常系 | build() | ✅ |
| 4 | 0件の状態で画面を開いた場合、画面の右下に FloatingActionButton が表示され、アイコンは Icons.add [SMP-D04] | SMP-D04 #47d48e | 正常系 | build() | ✅ |
| 5 | 「A」「B」の2件がある状態で画面を開いた場合、各行の右端に Icons.more_vert が1つずつ（計2つ）表示される [SMP-D05] | SMP-D05 #863896 | 正常系 | build() | ✅ |
| 6 | 0件の状態で画面を開いた場合、上から順に Icons.science_outlined、「サンプルがありません」、Icons.add と「サンプルを作成」のボタンが表示される。一覧の行は表示されない [SMP-D06] | SMP-D06 #77b4c0 | 正常系 | build() | ✅ |
| 7 | 「A」「B」の2件がある状態で画面を開いた場合、一覧に「A」「B」が表示される。「サンプルがありません」は表示されない [SMP-D07] | SMP-D07 #ed5d14 | 正常系 | build() | ✅ |
| 8 | 作成日時が古い順に「A」「B」「C」の3件がある状態で画面を開いた場合、一覧に上から「A」「B」「C」の順で表示される [SMP-D08] | SMP-D08 #62c9d6 | 正常系 | build() | ✅ |
| 9 | 作成日時が古い順に「S01」〜「S30」の30件がある状態で画面を開いた場合、一覧を下へスクロールすると「S30」が表示される [SMP-D09] | SMP-D09 #4cfa98 | 正常系 | build() | ✅ |
| 10 | 「あいうえおかきくけこ」（幅20）の1件がある状態で画面を開いた場合、一覧に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-D10] | SMP-D10 #2c4635 | 正常系 | build() | ✅ |
| 11 | 画面を開き、初期読み込みが完了していない場合、CircularProgressIndicator が表示される。一覧の行・「サンプルがありません」は表示されない [SMP-D11] | SMP-D11 #6cda29 | 境界値 | build() | ✅ |
| 12 | 画面を開き、初期読み込みが完了していない場合、FloatingActionButton は表示されない [SMP-D12] | SMP-D12 #dd8146 | 境界値 | build() | ✅ |
| 13 | 画面を開き、初期読み込みが UnknownFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D13] | SMP-D13 #a2c2c3 | 異常系 | build() | ✅ |
| 14 | 画面を開き、初期読み込みが UnknownFailure で失敗した場合、FloatingActionButton は表示されない [SMP-D14] | SMP-D14 #4afd49 | 異常系 | build() | ✅ |
| 15 | 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で、Repository が「A」の1件を返すようにして「再試行」をタップした場合、一覧に「A」が表示される。ErrorScreen は表示されない [SMP-D15] | SMP-D15 #133f5a | 異常系 | refresh() | ✅ |
| 16 | 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが完了していない場合、CircularProgressIndicator が表示される。「再試行」ボタンは表示されない [SMP-D16] | SMP-D16 #34fb40 | 異常系 | refresh() | ✅ |
| 17 | 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが再び UnknownFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D17] | SMP-D17 #a465f7 | 異常系 | refresh() | ✅ |
| 18 | 一覧に「A」の1件が表示され、Repository には「A」「B」（作成日時が古い順）がある状態で、一覧を下に引っ張って離した場合、一覧に上から「A」「B」の順で表示される [SMP-D18] | SMP-D18 #9ff856 | 正常系 | refresh() | ✅ |
| 19 | 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが完了していない場合、RefreshIndicator の読み込み表示が出る。一覧には「A」が表示されたまま [SMP-D19] | SMP-D19 #6d1b77 | 境界値 | refresh() | ✅ |
| 20 | 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが UnknownFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。ErrorScreen は表示されない [SMP-D20] | SMP-D20 #568d0e | 異常系 | refresh() | ✅ |
| 21 | 一覧に「A」の1件が表示されている状態で、プルして更新を2回続けて行い、2回とも UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-D21] | SMP-D21 #a6950a | 異常系 | refresh() | ✅ |
| 22 | 0件の状態（「サンプルがありません」表示中）で、Repository に「A」が追加された状態にして、画面を下に引っ張って離した場合、一覧に「A」が表示される。「サンプルがありません」は表示されない [SMP-D22] | SMP-D22 #6e7f99 | 正常系 | refresh() | ✅ |
| 23 | 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、「編集」「削除」が表示される [SMP-D23] | SMP-D23 #9e2d05 | 正常系 | SampleListTile（メニュー） | ✅ |
| 24 | 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、上から「編集」「削除」の順で表示される [SMP-D24] | SMP-D24 #354165 | 正常系 | SampleListTile（メニュー） | ✅ |
| 25 | 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、メニューの外側をタップした場合、「編集」「削除」は表示されない。一覧は「A」の1件のまま [SMP-D25] | SMP-D25 #f98002 | 正常系 | SampleListTile（メニュー） | ✅ |
| 26 | 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、端末の戻る操作をした場合、「編集」「削除」は表示されない。一覧は「A」の1件のまま。パスは /sample のまま [SMP-D26] | SMP-D26 #5d7321 | 正常系 | SampleListTile（メニュー） | ✅ |
| 27 | 「B」「A」の順（B が上の行）で2件がある状態で、下の行「A」の Icons.more_vert をタップしてメニューを開き、続けて上の行「B」の Icons.more_vert をタップした場合、「A」のメニューが閉じ、「編集」「削除」は表示されない（「B」のメニューは開かない）。一覧は「B」「A」の2件のまま [SMP-D27] | SMP-D27 #2e19fd | 正常系 | SampleListTile（メニュー） | ✅ |
| 28 | 「A」の1件がある状態で FloatingActionButton をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効 [SMP-C01] | SMP-C01 #dc1042 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 29 | 0件の状態で「サンプルを作成」ボタンをタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効 [SMP-C02] | SMP-C02 #3eb629 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 30 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される [SMP-C03] | SMP-C03 #82fc74 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 31 | 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に「B」が表示される。「サンプルがありません」は表示されない [SMP-C04] | SMP-C04 #b59da6 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 32 | 「A」の1件がある状態で FloatingActionButton をタップし、「A」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に「A」「A」の2件が表示される [SMP-C05] | SMP-C05 #4db8ea | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 33 | 「A」の1件がある状態で FloatingActionButton をタップし、「 B 」（前後に半角スペース）を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない） [SMP-C06] | SMP-C06 #cce2c7 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 34 | 「A」の1件がある状態で FloatingActionButton をタップし、「　B　」（前後に全角スペース）を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない） [SMP-C07] | SMP-C07 #9952bc | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 35 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C08] | SMP-C08 #a486bb | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 36 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力してダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C09] | SMP-C09 #bd0e70 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 37 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C10] | SMP-C10 #432748 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 38 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、「作成」が無効になる [SMP-C11] | SMP-C11 #518a3a | 境界値 | createSample() / 作成ダイアログ | ✅ |
| 39 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して、作成の完了前に「作成」を2回続けてタップした場合、ダイアログが閉じる。一覧に「A」「B」の2件が表示される（「B」は1件だけ） [SMP-C12] | SMP-C12 #a65c0e | 境界値 | createSample() / 作成ダイアログ | ✅ |
| 40 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、ダイアログ内に CircularProgressIndicator は表示されない [SMP-C13] | SMP-C13 #3be8a5 | 境界値 | createSample() / 作成ダイアログ | ✅ |
| 41 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、「キャンセル」が無効になる [SMP-C14] | SMP-C14 #64416d | 境界値 | createSample() / 作成ダイアログ | ✅ |
| 42 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-C15] | SMP-C15 #f6ec8f | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 43 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-C16] | SMP-C16 #f2c87c | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 44 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま [SMP-C17] | SMP-C17 #100517 | 異常系 | createSample() / 作成ダイアログ | ✅ |
| 45 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、UnknownFailure で失敗した後、もう一度「作成」をタップして再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-C18] | SMP-C18 #a2ab6e | 異常系 | createSample() / 作成ダイアログ | ✅ |
| 46 | 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示されたまま [SMP-C19] | SMP-C19 #4d3a02 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 47 | 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。ダイアログの背後には「サンプルがありません」が表示されたまま [SMP-C20] | SMP-C20 #620fcc | 異常系 | createSample() / 作成ダイアログ | ✅ |
| 48 | 「A」の1件がある状態で FloatingActionButton をタップし、「あいうえおかきくけこ」（幅20）を入力した場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-C21] | SMP-C21 #a05c77 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 49 | 作成日時が古い順に「S01」〜「S30」の30件があり、一覧の先頭（「S01」）が表示されている状態で、FloatingActionButton をタップし、「S31」を入力して「作成」をタップした場合、ダイアログが閉じる。スクロール操作をしなくても、画面内に「S31」が表示される [SMP-C22] | SMP-C22 #3cdb56 | 正常系 | createSample() / 作成ダイアログ | ✅ |
| 50 | 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「編集」をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを編集」、入力項目タイトル「サンプル名」、「A」が入った入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「保存」（右）が表示される。「保存」は有効 [SMP-U01] | SMP-U01 #83dafd | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 51 | 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「編集」をタップした場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-U02] | SMP-U02 #370733 | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 52 | 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」「C」の順で表示される [SMP-U03] | SMP-U03 #1b63b7 | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 53 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「A」に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に「A」「A」の2件が表示される [SMP-U04] | SMP-U04 #916e17 | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 54 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を変えずに「保存」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U05] | SMP-U05 #d16069 | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 55 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「 X 」（前後に半角スペース）に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない） [SMP-U06] | SMP-U06 #c1e60a | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 56 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「　X　」（前後に全角スペース）に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない） [SMP-U07] | SMP-U07 #7cb27d | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 57 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U08] | SMP-U08 #13b1bc | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 58 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えてダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U09] | SMP-U09 #89bfaf | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 59 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U10] | SMP-U10 #e39901 | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 60 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、「保存」が無効になる [SMP-U11] | SMP-U11 #707277 | 境界値 | updateSample() / 編集ダイアログ | ✅ |
| 61 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて、変更の完了前に「保存」を2回続けてタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の2件が表示される [SMP-U12] | SMP-U12 #e1a9df | 境界値 | updateSample() / 編集ダイアログ | ✅ |
| 62 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、ダイアログ内に CircularProgressIndicator は表示されない [SMP-U13] | SMP-U13 #35864d | 境界値 | updateSample() / 編集ダイアログ | ✅ |
| 63 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、「キャンセル」が無効になる [SMP-U14] | SMP-U14 #e19e0e | 境界値 | updateSample() / 編集ダイアログ | ✅ |
| 64 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-U15] | SMP-U15 #fe360e | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 65 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-U16] | SMP-U16 #eb14f2 | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 66 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残り、「保存」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま [SMP-U17] | SMP-U17 #be29e3 | 異常系 | updateSample() / 編集ダイアログ | ✅ |
| 67 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、UnknownFailure で失敗した後、もう一度「保存」をタップして再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-U18] | SMP-U18 #263b10 | 異常系 | updateSample() / 編集ダイアログ | ✅ |
| 68 | 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を空にしてから「あいうえおかきくけこ」（幅20）を入力した場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-U19] | SMP-U19 #c90c51 | 正常系 | updateSample() / 編集ダイアログ | ✅ |
| 69 | 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「削除」をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを削除」、注記「※「A」を削除しますか？」、横並びの「キャンセル」（左）と「削除」（右）が表示される [SMP-X01] | SMP-X01 #a95d2f | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 70 | 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「削除」をタップした場合、注記「※「あいうえおかきくけこ」を削除しますか？」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-X02] | SMP-X02 #ad23ea | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 71 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に「B」の1件だけが表示される [SMP-X03] | SMP-X03 #b36bf8 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 72 | 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に上から「A」「C」の順で表示される [SMP-X04] | SMP-X04 #38cd7d | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 73 | 「A」の1件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示される [SMP-X05] | SMP-X05 #c3671e | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 74 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X06] | SMP-X06 #177cf1 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 75 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いてダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X07] | SMP-X07 #e9ee72 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 76 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X08] | SMP-X08 #2c6f66 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 77 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、削除ダイアログ（「サンプルを削除」）は表示されていない [SMP-X09] | SMP-X09 #b18ea6 | 境界値 | deleteSample() / 削除ダイアログ | ✅ |
| 78 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、画面に CircularProgressIndicator は表示されない [SMP-X10] | SMP-X10 #1aaf4d | 境界値 | deleteSample() / 削除ダイアログ | ✅ |
| 79 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が UnknownFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま [SMP-X11] | SMP-X11 #0c98dd | 異常系 | deleteSample() / 削除ダイアログ | ✅ |
| 80 | 「A」「B」の2件がある状態で、「A」を削除して UnknownFailure で失敗した後、もう一度「A」の削除ダイアログを開いて「削除」をタップし、再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-X12] | SMP-X12 #f313ed | 異常系 | deleteSample() / 削除ダイアログ | ✅ |
| 81 | 一覧に「A」「B」が表示され、Repository 上では「A」が既に削除されている状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に「B」の1件だけが表示される。「操作が失敗しました。」は表示されない [SMP-X13] | SMP-X13 #14d8ed | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 82 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「A」の Icons.more_vert をタップした場合、「編集」「削除」のメニューは表示されない（「A」の Icons.more_vert は無効） [SMP-X14] | SMP-X14 #efcee0 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 83 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に FloatingActionButton から「C」を作成して、作成と削除の両方が成功した場合、両方の完了後、一覧に上から「B」「C」の順で表示される。「A」は表示されない [SMP-X15] | SMP-X15 #2eda12 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 84 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧を下に引っ張って離し、プルして更新の読み込みが削除前の「A」「B」を返して削除の完了より後に終わった場合、両方の完了後、一覧に「B」の1件だけが表示される。「A」は表示されない [SMP-X16] | SMP-X16 #025ac6 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 85 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧の「B」をタップした場合、遷移先のパスが /folder/<B の id> になり、遷移先に渡される $extra が「B」 [SMP-X17] | SMP-X17 #e162c0 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 86 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「B」の Icons.more_vert をタップした場合、「編集」「削除」が表示される [SMP-X18] | SMP-X18 #398700 | 正常系 | deleteSample() / 削除ダイアログ | ✅ |
| 87 | id が「sample-1」、名前が「A」の1件がある状態で、一覧の「A」をタップした場合、遷移先のパスが /folder/sample-1 になり、遷移先に渡される $extra が「A」 [SMP-T01] | SMP-T01 #4cc9d4 | 正常系 | onTap() / FolderRoute | ✅ |
| 88 | 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、遷移しない（パスは /sample のまま）。「編集」「削除」が表示される [SMP-T02] | SMP-T02 #b903bd | 正常系 | onTap() / FolderRoute | ✅ |
| 89 | 画面を開き、初期読み込みが NotFoundFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E01] | SMP-E01 #22032c | 異常系 | ref.listen(operationFailure) | ✅ |
| 90 | 画面を開き、初期読み込みが NetworkFailure で失敗した場合、NetworkErrorDialog が表示される。ErrorScreen は表示されない [SMP-E02] | SMP-E02 #45c25a | 異常系 | ref.listen(operationFailure) | ✅ |
| 91 | 初期読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E03] | SMP-E03 #9f47ee | 異常系 | ref.listen(operationFailure) | ✅ |
| 92 | 画面を開き、初期読み込みが AuthFailure で失敗した場合、NetworkErrorDialog が表示される。ErrorScreen は表示されない [SMP-E04] | SMP-E04 #f229e5 | 異常系 | ref.listen(operationFailure) | ✅ |
| 93 | 初期読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E05] | SMP-E05 #6a940c | 異常系 | ref.listen(operationFailure) | ✅ |
| 94 | 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NotFoundFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E06] | SMP-E06 #df1621 | 異常系 | ref.listen(operationFailure) | ✅ |
| 95 | 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NetworkFailure で失敗した場合、NetworkErrorDialog が表示される [SMP-E07] | SMP-E07 #21a7fa | 異常系 | ref.listen(operationFailure) | ✅ |
| 96 | 「再試行」後の読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E08] | SMP-E08 #931111 | 異常系 | ref.listen(operationFailure) | ✅ |
| 97 | 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが AuthFailure で失敗した場合、NetworkErrorDialog が表示される [SMP-E09] | SMP-E09 #3affc6 | 異常系 | ref.listen(operationFailure) | ✅ |
| 98 | 「再試行」後の読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E10] | SMP-E10 #b054f2 | 異常系 | ref.listen(operationFailure) | ✅ |
| 99 | 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NotFoundFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま [SMP-E11] | SMP-E11 #e3124f | 異常系 | ref.listen(operationFailure) | ✅ |
| 100 | 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NetworkFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない [SMP-E12] | SMP-E12 #ca70a5 | 異常系 | ref.listen(operationFailure) | ✅ |
| 101 | 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが AuthFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない [SMP-E13] | SMP-E13 #a44684 | 異常系 | ref.listen(operationFailure) | ✅ |
| 102 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が NetworkFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない [SMP-E14] | SMP-E14 #99c73e | 異常系 | ref.listen(operationFailure) | ✅ |
| 103 | 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が AuthFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない [SMP-E15] | SMP-E15 #1c678c | 異常系 | ref.listen(operationFailure) | ✅ |
| 104 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NotFoundFailure で失敗した（「B」が既に削除されていた）場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま [SMP-E16] | SMP-E16 #3bfa13 | 異常系 | ref.listen(operationFailure) | ✅ |
| 105 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NetworkFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない [SMP-E17] | SMP-E17 #6ecc7a | 異常系 | ref.listen(operationFailure) | ✅ |
| 106 | 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が AuthFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない [SMP-E18] | SMP-E18 #e7c21f | 異常系 | ref.listen(operationFailure) | ✅ |
| 107 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NotFoundFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま [SMP-E19] | SMP-E19 #b0cb4d | 異常系 | ref.listen(operationFailure) | ✅ |
| 108 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NetworkFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない [SMP-E20] | SMP-E20 #5d949d | 異常系 | ref.listen(operationFailure) | ✅ |
| 109 | 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が AuthFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない [SMP-E21] | SMP-E21 #5f1935 | 異常系 | ref.listen(operationFailure) | ✅ |
| 110 | 作成ダイアログの入力欄に「B」（幅1）を入力した場合、「作成」は有効になる [SMP-N01] | SMP-N01 #8ee868 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 111 | 作成ダイアログの入力欄に「 B 」（幅3）を入力した場合、「作成」は有効になる [SMP-N01] | SMP-N01 #8ee868 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 112 | 作成ダイアログの入力欄に「」（空）を入力した場合、「作成」は無効になる [SMP-N01] | SMP-N01 #8ee868 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 113 | 作成ダイアログの入力欄に「   」（半角スペース3つ）を入力した場合、「作成」は無効になる [SMP-N01] | SMP-N01 #8ee868 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 114 | 作成ダイアログの入力欄に「　　」（全角スペース2つ）を入力した場合、「作成」は無効になる [SMP-N01] | SMP-N01 #8ee868 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 115 | 作成ダイアログの入力欄に「 　 」（半角・全角スペースの混在）を入力した場合、「作成」は無効になる [SMP-N01] | SMP-N01 #8ee868 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 116 | 作成ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、入力欄はそのまま「abcdefghijklmnopqrst」になる [SMP-N02] | SMP-N02 #073b95 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 117 | 作成ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、入力欄はそのまま「あいうえおかきくけこ」になる [SMP-N02] | SMP-N02 #073b95 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 118 | 作成ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、入力欄はそのまま「あいうえおabcdefghij」になる [SMP-N02] | SMP-N02 #073b95 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 119 | 作成ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N02] | SMP-N02 #073b95 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 120 | 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N02] | SMP-N02 #073b95 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 121 | 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N02] | SMP-N02 #073b95 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 122 | 作成ダイアログの空の入力欄に「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N02] | SMP-N02 #073b95 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 123 | 作成ダイアログの空の状態で「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N02] | SMP-N02 #073b95 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 124 | 編集ダイアログの入力欄に「X」（幅1）を入力した場合、「保存」は有効になる [SMP-N03] | SMP-N03 #3349aa | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 125 | 編集ダイアログの入力欄に「 X 」（幅3）を入力した場合、「保存」は有効になる [SMP-N03] | SMP-N03 #3349aa | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 126 | 編集ダイアログの入力欄に「」（空）を入力した場合、「保存」は無効になる [SMP-N03] | SMP-N03 #3349aa | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 127 | 編集ダイアログの入力欄に「   」（半角スペース3つ）を入力した場合、「保存」は無効になる [SMP-N03] | SMP-N03 #3349aa | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 128 | 編集ダイアログの入力欄に「　　」（全角スペース2つ）を入力した場合、「保存」は無効になる [SMP-N03] | SMP-N03 #3349aa | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 129 | 編集ダイアログの入力欄に「 　 」（半角・全角スペースの混在）を入力した場合、「保存」は無効になる [SMP-N03] | SMP-N03 #3349aa | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 130 | 編集ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、入力欄はそのまま「abcdefghijklmnopqrst」になる [SMP-N04] | SMP-N04 #41e956 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 131 | 編集ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、入力欄はそのまま「あいうえおかきくけこ」になる [SMP-N04] | SMP-N04 #41e956 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 132 | 編集ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、入力欄はそのまま「あいうえおabcdefghij」になる [SMP-N04] | SMP-N04 #41e956 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 133 | 編集ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N04] | SMP-N04 #41e956 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 134 | 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N04] | SMP-N04 #41e956 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 135 | 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N04] | SMP-N04 #41e956 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 136 | 編集ダイアログの入力欄を空にしてから「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N04] | SMP-N04 #41e956 | 正常系 | FolderNameLengthFormatter / 入力欄 | ✅ |
| 137 | 編集ダイアログの入力欄を空にしてから「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N04] | SMP-N04 #41e956 | 境界値 | FolderNameLengthFormatter / 入力欄 | ✅ |

## テストケース詳細

### テストケース1: 「A」の1件がある状態で画面を開いた場合、AppBar に「サンプル」と表示される [SMP-D01]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 「A」の1件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で画面を開いた場合、
- **期待結果**: AppBar に「サンプル」と表示される

### テストケース2: 「A」の1件がある状態で画面を開いた場合、ボトムナビゲーションバーが表示され、「テスト」タブが選択状態になっている [SMP-D02]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 「A」の1件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で画面を開いた場合、
- **期待結果**: ボトムナビゲーションバーが表示され、「テスト」タブが選択状態になっている

### テストケース3: 「A」の1件がある状態で画面を開いた場合、画面の右下に FloatingActionButton が表示され、アイコンは Icons.add [SMP-D03]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 「A」の1件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で画面を開いた場合、
- **期待結果**: 画面の右下に FloatingActionButton が表示され、アイコンは Icons.add

### テストケース4: 0件の状態で画面を開いた場合、画面の右下に FloatingActionButton が表示され、アイコンは Icons.add [SMP-D04]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 0件の状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 0件の状態で画面を開いた場合、
- **期待結果**: 画面の右下に FloatingActionButton が表示され、アイコンは Icons.add

### テストケース5: 「A」「B」の2件がある状態で画面を開いた場合、各行の右端に Icons.more_vert が1つずつ（計2つ）表示される [SMP-D05]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 「A」「B」の2件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で画面を開いた場合、
- **期待結果**: 各行の右端に Icons.more_vert が1つずつ（計2つ）表示される

### テストケース6: 0件の状態で画面を開いた場合、上から順に Icons.science_outlined、「サンプルがありません」、Icons.add と「サンプルを作成」のボタンが表示される。一覧の行は表示されない [SMP-D06]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 0件の状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 0件の状態で画面を開いた場合、
- **期待結果**: 上から順に Icons.science_outlined、「サンプルがありません」、Icons.add と「サンプルを作成」のボタンが表示される。一覧の行は表示されない

### テストケース7: 「A」「B」の2件がある状態で画面を開いた場合、一覧に「A」「B」が表示される。「サンプルがありません」は表示されない [SMP-D07]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 「A」「B」の2件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で画面を開いた場合、
- **期待結果**: 一覧に「A」「B」が表示される。「サンプルがありません」は表示されない

### テストケース8: 作成日時が古い順に「A」「B」「C」の3件がある状態で画面を開いた場合、一覧に上から「A」「B」「C」の順で表示される [SMP-D08]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 作成日時が古い順に「A」「B」「C」の3件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成日時が古い順に「A」「B」「C」の3件がある状態で画面を開いた場合、
- **期待結果**: 一覧に上から「A」「B」「C」の順で表示される

### テストケース9: 作成日時が古い順に「S01」〜「S30」の30件がある状態で画面を開いた場合、一覧を下へスクロールすると「S30」が表示される [SMP-D09]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 作成日時が古い順に「S01」〜「S30」の30件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成日時が古い順に「S01」〜「S30」の30件がある状態で画面を開いた場合、
- **期待結果**: 一覧を下へスクロールすると「S30」が表示される

### テストケース10: 「あいうえおかきくけこ」（幅20）の1件がある状態で画面を開いた場合、一覧に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-D10]
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 「あいうえおかきくけこ」（幅20）の1件がある状態で画面を開いた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「あいうえおかきくけこ」（幅20）の1件がある状態で画面を開いた場合、
- **期待結果**: 一覧に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない

### テストケース11: 画面を開き、初期読み込みが完了していない場合、CircularProgressIndicator が表示される。一覧の行・「サンプルがありません」は表示されない [SMP-D11]
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: 画面を開き、初期読み込みが完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 画面を開き、初期読み込みが完了していない場合、
- **期待結果**: CircularProgressIndicator が表示される。一覧の行・「サンプルがありません」は表示されない

### テストケース12: 画面を開き、初期読み込みが完了していない場合、FloatingActionButton は表示されない [SMP-D12]
- **カテゴリ**: 境界値
- **対象メソッド**: build()
- **事前条件**: 画面を開き、初期読み込みが完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 画面を開き、初期読み込みが完了していない場合、
- **期待結果**: FloatingActionButton は表示されない

### テストケース13: 画面を開き、初期読み込みが UnknownFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D13]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: 画面を開き、初期読み込みが UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 画面を開き、初期読み込みが UnknownFailure で失敗した場合、
- **期待結果**: ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される

### テストケース14: 画面を開き、初期読み込みが UnknownFailure で失敗した場合、FloatingActionButton は表示されない [SMP-D14]
- **カテゴリ**: 異常系
- **対象メソッド**: build()
- **事前条件**: 画面を開き、初期読み込みが UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 画面を開き、初期読み込みが UnknownFailure で失敗した場合、
- **期待結果**: FloatingActionButton は表示されない

### テストケース15: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で、Repository が「A」の1件を返すようにして「再試行」をタップした場合、一覧に「A」が表示される。ErrorScreen は表示されない [SMP-D15]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で、Repository が「A」の1件を返すようにして「再試行」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で、Repository が「A」の1件を返すようにして「再試行」をタップした場合、
- **期待結果**: 一覧に「A」が表示される。ErrorScreen は表示されない

### テストケース16: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが完了していない場合、CircularProgressIndicator が表示される。「再試行」ボタンは表示されない [SMP-D16]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが完了していない場合、
- **期待結果**: CircularProgressIndicator が表示される。「再試行」ボタンは表示されない

### テストケース17: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが再び UnknownFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-D17]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが再び UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが再び UnknownFailure で失敗した場合、
- **期待結果**: ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される

### テストケース18: 一覧に「A」の1件が表示され、Repository には「A」「B」（作成日時が古い順）がある状態で、一覧を下に引っ張って離した場合、一覧に上から「A」「B」の順で表示される [SMP-D18]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: 一覧に「A」の1件が表示され、Repository には「A」「B」（作成日時が古い順）がある状態で、一覧を下に引っ張って離した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」の1件が表示され、Repository には「A」「B」（作成日時が古い順）がある状態で、一覧を下に引っ張って離した場合、
- **期待結果**: 一覧に上から「A」「B」の順で表示される

### テストケース19: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが完了していない場合、RefreshIndicator の読み込み表示が出る。一覧には「A」が表示されたまま [SMP-D19]
- **カテゴリ**: 境界値
- **対象メソッド**: refresh()
- **事前条件**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが完了していない場合、
- **期待結果**: RefreshIndicator の読み込み表示が出る。一覧には「A」が表示されたまま

### テストケース20: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが UnknownFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。ErrorScreen は表示されない [SMP-D20]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが UnknownFailure で失敗した場合、
- **期待結果**: スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。ErrorScreen は表示されない

### テストケース21: 一覧に「A」の1件が表示されている状態で、プルして更新を2回続けて行い、2回とも UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-D21]
- **カテゴリ**: 異常系
- **対象メソッド**: refresh()
- **事前条件**: 一覧に「A」の1件が表示されている状態で、プルして更新を2回続けて行い、2回とも UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」の1件が表示されている状態で、プルして更新を2回続けて行い、2回とも UnknownFailure で失敗した場合、
- **期待結果**: 「操作が失敗しました。」のスナックバーが2回表示される

### テストケース22: 0件の状態（「サンプルがありません」表示中）で、Repository に「A」が追加された状態にして、画面を下に引っ張って離した場合、一覧に「A」が表示される。「サンプルがありません」は表示されない [SMP-D22]
- **カテゴリ**: 正常系
- **対象メソッド**: refresh()
- **事前条件**: 0件の状態（「サンプルがありません」表示中）で、Repository に「A」が追加された状態にして、画面を下に引っ張って離した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 0件の状態（「サンプルがありません」表示中）で、Repository に「A」が追加された状態にして、画面を下に引っ張って離した場合、
- **期待結果**: 一覧に「A」が表示される。「サンプルがありません」は表示されない

### テストケース23: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、「編集」「削除」が表示される [SMP-D23]
- **カテゴリ**: 正常系
- **対象メソッド**: SampleListTile（メニュー）
- **事前条件**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、
- **期待結果**: 「編集」「削除」が表示される

### テストケース24: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、上から「編集」「削除」の順で表示される [SMP-D24]
- **カテゴリ**: 正常系
- **対象メソッド**: SampleListTile（メニュー）
- **事前条件**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、
- **期待結果**: 上から「編集」「削除」の順で表示される

### テストケース25: 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、メニューの外側をタップした場合、「編集」「削除」は表示されない。一覧は「A」の1件のまま [SMP-D25]
- **カテゴリ**: 正常系
- **対象メソッド**: SampleListTile（メニュー）
- **事前条件**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、メニューの外側をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、メニューの外側をタップした場合、
- **期待結果**: 「編集」「削除」は表示されない。一覧は「A」の1件のまま

### テストケース26: 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、端末の戻る操作をした場合、「編集」「削除」は表示されない。一覧は「A」の1件のまま。パスは /sample のまま [SMP-D26]
- **カテゴリ**: 正常系
- **対象メソッド**: SampleListTile（メニュー）
- **事前条件**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、端末の戻る操作をした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップしてメニューを開き、端末の戻る操作をした場合、
- **期待結果**: 「編集」「削除」は表示されない。一覧は「A」の1件のまま。パスは /sample のまま

### テストケース27: 「B」「A」の順（B が上の行）で2件がある状態で、下の行「A」の Icons.more_vert をタップしてメニューを開き、続けて上の行「B」の Icons.more_vert をタップした場合、「A」のメニューが閉じ、「編集」「削除」は表示されない（「B」のメニューは開かない）。一覧は「B」「A」の2件のまま [SMP-D27]
- **カテゴリ**: 正常系
- **対象メソッド**: SampleListTile（メニュー）
- **事前条件**: B を先に作成し上の行、A を後に作成し下の行にする。仕様の並び順は固定されていないため、ヒットテストの都合（A のメニューは下向きに開くため、A が上の行だと下の行「B」の Icons.more_vert をメニューが覆ってしまい、B をタップしたつもりの座標が実際は A 自身のメニュー項目に当たる）でこの並びを選んでいる
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）に B・A をこの順で登録
- **操作手順**: 下の行「A」の Icons.more_vert をタップしてメニューを開く → 「A」のメニューが上の行「B」の Icons.more_vert を覆っていないことを矩形の重なりで確認する → 上の行「B」の Icons.more_vert をタップする
- **期待結果**: 「A」のメニューが閉じ、「編集」「削除」は表示されない（「B」のメニューは開かない）。一覧は「B」「A」の2件のまま

### テストケース28: 「A」の1件がある状態で FloatingActionButton をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効 [SMP-C01]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップした場合、
- **期待結果**: ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効

### テストケース29: 0件の状態で「サンプルを作成」ボタンをタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効 [SMP-C02]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 0件の状態で「サンプルを作成」ボタンをタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 0件の状態で「サンプルを作成」ボタンをタップした場合、
- **期待結果**: ダイアログが表示され、上から順にタイトル「サンプルを作成」、入力項目タイトル「サンプル名」、空の入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「作成」（右）が表示される。「作成」は無効

### テストケース30: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される [SMP-C03]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「B」の順で表示される

### テストケース31: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に「B」が表示される。「サンプルがありません」は表示されない [SMP-C04]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に「B」が表示される。「サンプルがありません」は表示されない

### テストケース32: 「A」の1件がある状態で FloatingActionButton をタップし、「A」を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に「A」「A」の2件が表示される [SMP-C05]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「A」を入力して「作成」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「A」を入力して「作成」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に「A」「A」の2件が表示される

### テストケース33: 「A」の1件がある状態で FloatingActionButton をタップし、「 B 」（前後に半角スペース）を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない） [SMP-C06]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「 B 」（前後に半角スペース）を入力して「作成」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「 B 」（前後に半角スペース）を入力して「作成」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない）

### テストケース34: 「A」の1件がある状態で FloatingActionButton をタップし、「　B　」（前後に全角スペース）を入力して「作成」をタップした場合、ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない） [SMP-C07]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「　B　」（前後に全角スペース）を入力して「作成」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「　B　」（前後に全角スペース）を入力して「作成」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「B」の順で表示される（「B」の前後に空白はない）

### テストケース35: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C08]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「キャンセル」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「キャンセル」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」の1件のまま

### テストケース36: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力してダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C09]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力してダイアログの外側をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力してダイアログの外側をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」の1件のまま

### テストケース37: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-C10]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して端末の戻る操作をした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して端末の戻る操作をした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」の1件のまま

### テストケース38: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、「作成」が無効になる [SMP-C11]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、
- **期待結果**: 「作成」が無効になる

### テストケース39: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して、作成の完了前に「作成」を2回続けてタップした場合、ダイアログが閉じる。一覧に「A」「B」の2件が表示される（「B」は1件だけ） [SMP-C12]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して、作成の完了前に「作成」を2回続けてタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して、作成の完了前に「作成」を2回続けてタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に「A」「B」の2件が表示される（「B」は1件だけ）

### テストケース40: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、ダイアログ内に CircularProgressIndicator は表示されない [SMP-C13]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、
- **期待結果**: ダイアログ内に CircularProgressIndicator は表示されない

### テストケース41: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、「キャンセル」が無効になる [SMP-C14]
- **カテゴリ**: 境界値
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が完了していない場合、
- **期待結果**: 「キャンセル」が無効になる

### テストケース42: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-C15]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前にダイアログの外側をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前にダイアログの外側をタップした場合、
- **期待結果**: ダイアログは閉じない

### テストケース43: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-C16]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前に端末の戻る操作をした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成の完了前に端末の戻る操作をした場合、
- **期待結果**: ダイアログは閉じない

### テストケース44: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま [SMP-C17]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、
- **期待結果**: ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま

### テストケース45: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、UnknownFailure で失敗した後、もう一度「作成」をタップして再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-C18]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、UnknownFailure で失敗した後、もう一度「作成」をタップして再び UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、UnknownFailure で失敗した後、もう一度「作成」をタップして再び UnknownFailure で失敗した場合、
- **期待結果**: 「操作が失敗しました。」のスナックバーが2回表示される

### テストケース46: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「キャンセル」をタップした場合、ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示されたまま [SMP-C19]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「キャンセル」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「キャンセル」をタップした場合、
- **期待結果**: ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示されたまま

### テストケース47: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。ダイアログの背後には「サンプルがありません」が表示されたまま [SMP-C20]
- **カテゴリ**: 異常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 0件の状態で「サンプルを作成」ボタンをタップし、「B」を入力して「作成」をタップし、作成が UnknownFailure で失敗した場合、
- **期待結果**: ダイアログは閉じず、入力欄に「B」が残り、「作成」は有効。スナックバーに「操作が失敗しました。」と表示される。ダイアログの背後には「サンプルがありません」が表示されたまま

### テストケース48: 「A」の1件がある状態で FloatingActionButton をタップし、「あいうえおかきくけこ」（幅20）を入力した場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-C21]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「あいうえおかきくけこ」（幅20）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「あいうえおかきくけこ」（幅20）を入力した場合、
- **期待結果**: 入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない

### テストケース49: 作成日時が古い順に「S01」〜「S30」の30件があり、一覧の先頭（「S01」）が表示されている状態で、FloatingActionButton をタップし、「S31」を入力して「作成」をタップした場合、ダイアログが閉じる。スクロール操作をしなくても、画面内に「S31」が表示される [SMP-C22]
- **カテゴリ**: 正常系
- **対象メソッド**: createSample() / 作成ダイアログ
- **事前条件**: 作成日時が古い順に「S01」〜「S30」の30件があり、一覧の先頭（「S01」）が表示されている状態で、FloatingActionButton をタップし、「S31」を入力して「作成」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成日時が古い順に「S01」〜「S30」の30件があり、一覧の先頭（「S01」）が表示されている状態で、FloatingActionButton をタップし、「S31」を入力して「作成」をタップした場合、
- **期待結果**: ダイアログが閉じる。スクロール操作をしなくても、画面内に「S31」が表示される

### テストケース50: 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「編集」をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを編集」、入力項目タイトル「サンプル名」、「A」が入った入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「保存」（右）が表示される。「保存」は有効 [SMP-U01]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「編集」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「編集」をタップした場合、
- **期待結果**: ダイアログが表示され、上から順にタイトル「サンプルを編集」、入力項目タイトル「サンプル名」、「A」が入った入力欄、注意書「半角20文字（全角10文字）まで」、横並びの「キャンセル」（左）と「保存」（右）が表示される。「保存」は有効

### テストケース51: 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「編集」をタップした場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-U02]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「編集」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「編集」をタップした場合、
- **期待結果**: 入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない

### テストケース52: 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」「C」の順で表示される [SMP-U03]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「X」「C」の順で表示される

### テストケース53: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「A」に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に「A」「A」の2件が表示される [SMP-U04]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「A」に変えて「保存」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「A」に変えて「保存」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に「A」「A」の2件が表示される

### テストケース54: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を変えずに「保存」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U05]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を変えずに「保存」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を変えずに「保存」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」の1件のまま

### テストケース55: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「 X 」（前後に半角スペース）に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない） [SMP-U06]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「 X 」（前後に半角スペース）に変えて「保存」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「 X 」（前後に半角スペース）に変えて「保存」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない）

### テストケース56: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「　X　」（前後に全角スペース）に変えて「保存」をタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない） [SMP-U07]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「　X　」（前後に全角スペース）に変えて「保存」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「　X　」（前後に全角スペース）に変えて「保存」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「X」の順で表示される（「X」の前後に空白はない）

### テストケース57: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U08]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「キャンセル」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「キャンセル」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」の1件のまま

### テストケース58: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えてダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U09]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えてダイアログの外側をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えてダイアログの外側をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」の1件のまま

### テストケース59: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」の1件のまま [SMP-U10]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて端末の戻る操作をした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて端末の戻る操作をした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」の1件のまま

### テストケース60: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、「保存」が無効になる [SMP-U11]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、
- **期待結果**: 「保存」が無効になる

### テストケース61: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて、変更の完了前に「保存」を2回続けてタップした場合、ダイアログが閉じる。一覧に上から「A」「X」の2件が表示される [SMP-U12]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて、変更の完了前に「保存」を2回続けてタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて、変更の完了前に「保存」を2回続けてタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「X」の2件が表示される

### テストケース62: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、ダイアログ内に CircularProgressIndicator は表示されない [SMP-U13]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、
- **期待結果**: ダイアログ内に CircularProgressIndicator は表示されない

### テストケース63: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、「キャンセル」が無効になる [SMP-U14]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が完了していない場合、
- **期待結果**: 「キャンセル」が無効になる

### テストケース64: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前にダイアログの外側をタップした場合、ダイアログは閉じない [SMP-U15]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前にダイアログの外側をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前にダイアログの外側をタップした場合、
- **期待結果**: ダイアログは閉じない

### テストケース65: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前に端末の戻る操作をした場合、ダイアログは閉じない [SMP-U16]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前に端末の戻る操作をした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更の完了前に端末の戻る操作をした場合、
- **期待結果**: ダイアログは閉じない

### テストケース66: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が UnknownFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残り、「保存」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま [SMP-U17]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が UnknownFailure で失敗した場合、
- **期待結果**: ダイアログは閉じず、入力欄に「X」が残り、「保存」は有効。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま

### テストケース67: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、UnknownFailure で失敗した後、もう一度「保存」をタップして再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-U18]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、UnknownFailure で失敗した後、もう一度「保存」をタップして再び UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、UnknownFailure で失敗した後、もう一度「保存」をタップして再び UnknownFailure で失敗した場合、
- **期待結果**: 「操作が失敗しました。」のスナックバーが2回表示される

### テストケース68: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を空にしてから「あいうえおかきくけこ」（幅20）を入力した場合、入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-U19]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample() / 編集ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を空にしてから「あいうえおかきくけこ」（幅20）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の編集ダイアログを開き、入力欄を空にしてから「あいうえおかきくけこ」（幅20）を入力した場合、
- **期待結果**: 入力欄に「あいうえおかきくけこ」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない

### テストケース69: 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「削除」をタップした場合、ダイアログが表示され、上から順にタイトル「サンプルを削除」、注記「※「A」を削除しますか？」、横並びの「キャンセル」（左）と「削除」（右）が表示される [SMP-X01]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「削除」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップして「削除」をタップした場合、
- **期待結果**: ダイアログが表示され、上から順にタイトル「サンプルを削除」、注記「※「A」を削除しますか？」、横並びの「キャンセル」（左）と「削除」（右）が表示される

### テストケース70: 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「削除」をタップした場合、注記「※「あいうえおかきくけこ」を削除しますか？」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない [SMP-X02]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「削除」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「あいうえおかきくけこ」（幅20）の1件がある状態で、その Icons.more_vert をタップして「削除」をタップした場合、
- **期待結果**: 注記「※「あいうえおかきくけこ」を削除しますか？」が表示され、描画のはみ出し（オーバーフロー）のエラーが発生しない

### テストケース71: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に「B」の1件だけが表示される [SMP-X03]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に「B」の1件だけが表示される

### テストケース72: 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に上から「A」「C」の順で表示される [SMP-X04]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の削除ダイアログを開いて「削除」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成日時が古い順に「A」「B」「C」の3件がある状態で、「B」の削除ダイアログを開いて「削除」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に上から「A」「C」の順で表示される

### テストケース73: 「A」の1件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示される [SMP-X05]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」の1件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、
- **期待結果**: ダイアログが閉じる。「サンプルがありません」と「サンプルを作成」ボタンが表示される

### テストケース74: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「キャンセル」をタップした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X06]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「キャンセル」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「キャンセル」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」「B」の2件のまま

### テストケース75: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いてダイアログの外側をタップした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X07]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いてダイアログの外側をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いてダイアログの外側をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」「B」の2件のまま

### テストケース76: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて端末の戻る操作をした場合、ダイアログが閉じる。一覧は「A」「B」の2件のまま [SMP-X08]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて端末の戻る操作をした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて端末の戻る操作をした場合、
- **期待結果**: ダイアログが閉じる。一覧は「A」「B」の2件のまま

### テストケース77: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、削除ダイアログ（「サンプルを削除」）は表示されていない [SMP-X09]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、
- **期待結果**: 削除ダイアログ（「サンプルを削除」）は表示されていない

### テストケース78: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、画面に CircularProgressIndicator は表示されない [SMP-X10]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が完了していない場合、
- **期待結果**: 画面に CircularProgressIndicator は表示されない

### テストケース79: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が UnknownFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま [SMP-X11]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が UnknownFailure で失敗した場合、
- **期待結果**: 削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま

### テストケース80: 「A」「B」の2件がある状態で、「A」を削除して UnknownFailure で失敗した後、もう一度「A」の削除ダイアログを開いて「削除」をタップし、再び UnknownFailure で失敗した場合、「操作が失敗しました。」のスナックバーが2回表示される [SMP-X12]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」を削除して UnknownFailure で失敗した後、もう一度「A」の削除ダイアログを開いて「削除」をタップし、再び UnknownFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」を削除して UnknownFailure で失敗した後、もう一度「A」の削除ダイアログを開いて「削除」をタップし、再び UnknownFailure で失敗した場合、
- **期待結果**: 「操作が失敗しました。」のスナックバーが2回表示される

### テストケース81: 一覧に「A」「B」が表示され、Repository 上では「A」が既に削除されている状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、ダイアログが閉じる。一覧に「B」の1件だけが表示される。「操作が失敗しました。」は表示されない [SMP-X13]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 一覧に「A」「B」が表示され、Repository 上では「A」が既に削除されている状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」「B」が表示され、Repository 上では「A」が既に削除されている状態で、「A」の削除ダイアログを開いて「削除」をタップした場合、
- **期待結果**: ダイアログが閉じる。一覧に「B」の1件だけが表示される。「操作が失敗しました。」は表示されない

### テストケース82: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「A」の Icons.more_vert をタップした場合、「編集」「削除」のメニューは表示されない（「A」の Icons.more_vert は無効） [SMP-X14]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「A」の Icons.more_vert をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「A」の Icons.more_vert をタップした場合、
- **期待結果**: 「編集」「削除」のメニューは表示されない（「A」の Icons.more_vert は無効）

### テストケース83: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に FloatingActionButton から「C」を作成して、作成と削除の両方が成功した場合、両方の完了後、一覧に上から「B」「C」の順で表示される。「A」は表示されない [SMP-X15]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に FloatingActionButton から「C」を作成して、作成と削除の両方が成功した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に FloatingActionButton から「C」を作成して、作成と削除の両方が成功した場合、
- **期待結果**: 両方の完了後、一覧に上から「B」「C」の順で表示される。「A」は表示されない

### テストケース84: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧を下に引っ張って離し、プルして更新の読み込みが削除前の「A」「B」を返して削除の完了より後に終わった場合、両方の完了後、一覧に「B」の1件だけが表示される。「A」は表示されない [SMP-X16]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧を下に引っ張って離し、プルして更新の読み込みが削除前の「A」「B」を返して削除の完了より後に終わった場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧を下に引っ張って離し、プルして更新の読み込みが削除前の「A」「B」を返して削除の完了より後に終わった場合、
- **期待結果**: 両方の完了後、一覧に「B」の1件だけが表示される。「A」は表示されない

### テストケース85: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧の「B」をタップした場合、遷移先のパスが /folder/<B の id> になり、遷移先に渡される $extra が「B」 [SMP-X17]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧の「B」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に一覧の「B」をタップした場合、
- **期待結果**: 遷移先のパスが /folder/<B の id> になり、遷移先に渡される $extra が「B」

### テストケース86: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「B」の Icons.more_vert をタップした場合、「編集」「削除」が表示される [SMP-X18]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample() / 削除ダイアログ
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「B」の Icons.more_vert をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除の完了前に「B」の Icons.more_vert をタップした場合、
- **期待結果**: 「編集」「削除」が表示される

### テストケース87: id が「sample-1」、名前が「A」の1件がある状態で、一覧の「A」をタップした場合、遷移先のパスが /folder/sample-1 になり、遷移先に渡される $extra が「A」 [SMP-T01]
- **カテゴリ**: 正常系
- **対象メソッド**: onTap() / FolderRoute
- **事前条件**: id が「sample-1」、名前が「A」の1件がある状態で、一覧の「A」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: id が「sample-1」、名前が「A」の1件がある状態で、一覧の「A」をタップした場合、
- **期待結果**: 遷移先のパスが /folder/sample-1 になり、遷移先に渡される $extra が「A」

### テストケース88: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、遷移しない（パスは /sample のまま）。「編集」「削除」が表示される [SMP-T02]
- **カテゴリ**: 正常系
- **対象メソッド**: onTap() / FolderRoute
- **事前条件**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で、「A」の Icons.more_vert をタップした場合、
- **期待結果**: 遷移しない（パスは /sample のまま）。「編集」「削除」が表示される

### テストケース89: 画面を開き、初期読み込みが NotFoundFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E01]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 画面を開き、初期読み込みが NotFoundFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 画面を開き、初期読み込みが NotFoundFailure で失敗した場合、
- **期待結果**: ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される

### テストケース90: 画面を開き、初期読み込みが NetworkFailure で失敗した場合、NetworkErrorDialog が表示される。ErrorScreen は表示されない [SMP-E02]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 画面を開き、初期読み込みが NetworkFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 画面を開き、初期読み込みが NetworkFailure で失敗した場合、
- **期待結果**: NetworkErrorDialog が表示される。ErrorScreen は表示されない

### テストケース91: 初期読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E03]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 初期読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **期待結果**: 遷移先のパスが /login になる

### テストケース92: 画面を開き、初期読み込みが AuthFailure で失敗した場合、NetworkErrorDialog が表示される。ErrorScreen は表示されない [SMP-E04]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 画面を開き、初期読み込みが AuthFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 画面を開き、初期読み込みが AuthFailure で失敗した場合、
- **期待結果**: NetworkErrorDialog が表示される。ErrorScreen は表示されない

### テストケース93: 初期読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E05]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 初期読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **期待結果**: 遷移先のパスが /login になる

### テストケース94: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NotFoundFailure で失敗した場合、ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される [SMP-E06]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NotFoundFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NotFoundFailure で失敗した場合、
- **期待結果**: ErrorScreen が表示され、「サンプルの読み込みに失敗しました」と「再試行」ボタンが表示される

### テストケース95: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NetworkFailure で失敗した場合、NetworkErrorDialog が表示される [SMP-E07]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NetworkFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが NetworkFailure で失敗した場合、
- **期待結果**: NetworkErrorDialog が表示される

### テストケース96: 「再試行」後の読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E08]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「再試行」後の読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「再試行」後の読み込みが NetworkFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **期待結果**: 遷移先のパスが /login になる

### テストケース97: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが AuthFailure で失敗した場合、NetworkErrorDialog が表示される [SMP-E09]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが AuthFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 初期読み込みが UnknownFailure で失敗して ErrorScreen が表示された状態で「再試行」をタップし、読み込みが AuthFailure で失敗した場合、
- **期待結果**: NetworkErrorDialog が表示される

### テストケース98: 「再試行」後の読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、遷移先のパスが /login になる [SMP-E10]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「再試行」後の読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「再試行」後の読み込みが AuthFailure で失敗して NetworkErrorDialog が表示された状態で「OK」をタップした場合、
- **期待結果**: 遷移先のパスが /login になる

### テストケース99: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NotFoundFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま [SMP-E11]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NotFoundFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NotFoundFailure で失敗した場合、
- **期待結果**: スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま

### テストケース100: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NetworkFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない [SMP-E12]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NetworkFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが NetworkFailure で失敗した場合、
- **期待結果**: スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない

### テストケース101: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが AuthFailure で失敗した場合、スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない [SMP-E13]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが AuthFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 一覧に「A」の1件が表示されている状態で一覧を下に引っ張って離し、読み込みが AuthFailure で失敗した場合、
- **期待結果**: スナックバーに「操作が失敗しました。」と表示される。一覧には「A」が表示されたまま。NetworkErrorDialog は表示されない

### テストケース102: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が NetworkFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない [SMP-E14]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が NetworkFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が NetworkFailure で失敗した場合、
- **期待結果**: ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない

### テストケース103: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が AuthFailure で失敗した場合、ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない [SMP-E15]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が AuthFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」の1件がある状態で FloatingActionButton をタップし、「B」を入力して「作成」をタップし、作成が AuthFailure で失敗した場合、
- **期待結果**: ダイアログは閉じず、入力欄に「B」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」の1件のまま。NetworkErrorDialog は表示されない

### テストケース104: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NotFoundFailure で失敗した（「B」が既に削除されていた）場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま [SMP-E16]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NotFoundFailure で失敗した（「B」が既に削除されていた）場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NotFoundFailure で失敗した（「B」が既に削除されていた）場合、
- **期待結果**: ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま

### テストケース105: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NetworkFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない [SMP-E17]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NetworkFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が NetworkFailure で失敗した場合、
- **期待結果**: ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない

### テストケース106: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が AuthFailure で失敗した場合、ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない [SMP-E18]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が AuthFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「B」の編集ダイアログを開き、入力欄を「X」に変えて「保存」をタップし、変更が AuthFailure で失敗した場合、
- **期待結果**: ダイアログは閉じず、入力欄に「X」が残る。スナックバーに「操作が失敗しました。」と表示される。一覧は上から「A」「B」のまま。NetworkErrorDialog は表示されない

### テストケース107: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NotFoundFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま [SMP-E19]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NotFoundFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NotFoundFailure で失敗した場合、
- **期待結果**: 削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま

### テストケース108: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NetworkFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない [SMP-E20]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NetworkFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が NetworkFailure で失敗した場合、
- **期待結果**: 削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない

### テストケース109: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が AuthFailure で失敗した場合、削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない [SMP-E21]
- **カテゴリ**: 異常系
- **対象メソッド**: ref.listen(operationFailure)
- **事前条件**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が AuthFailure で失敗した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 「A」「B」の2件がある状態で、「A」の削除ダイアログを開いて「削除」をタップし、削除が AuthFailure で失敗した場合、
- **期待結果**: 削除ダイアログは表示されていない。スナックバーに「操作が失敗しました。」と表示される。一覧は「A」「B」の2件のまま。NetworkErrorDialog は表示されない

### テストケース110: 作成ダイアログの入力欄に「B」（幅1）を入力した場合、「作成」は有効になる [SMP-N01]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの入力欄に「B」（幅1）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの入力欄に「B」（幅1）を入力した場合、
- **期待結果**: 「作成」は有効になる

### テストケース111: 作成ダイアログの入力欄に「 B 」（幅3）を入力した場合、「作成」は有効になる [SMP-N01]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの入力欄に「 B 」（幅3）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの入力欄に「 B 」（幅3）を入力した場合、
- **期待結果**: 「作成」は有効になる

### テストケース112: 作成ダイアログの入力欄に「」（空）を入力した場合、「作成」は無効になる [SMP-N01]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの入力欄に「」（幅0）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの入力欄に「」（幅0）を入力した場合、
- **期待結果**: 「作成」は無効になる

### テストケース113: 作成ダイアログの入力欄に「   」（半角スペース3つ）を入力した場合、「作成」は無効になる [SMP-N01]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの入力欄に「   」（幅3）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの入力欄に「   」（幅3）を入力した場合、
- **期待結果**: 「作成」は無効になる

### テストケース114: 作成ダイアログの入力欄に「　　」（全角スペース2つ）を入力した場合、「作成」は無効になる [SMP-N01]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの入力欄に「　　」（幅2）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの入力欄に「　　」（幅2）を入力した場合、
- **期待結果**: 「作成」は無効になる

### テストケース115: 作成ダイアログの入力欄に「 　 」（半角・全角スペースの混在）を入力した場合、「作成」は無効になる [SMP-N01]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの入力欄に「 　 」（幅3）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの入力欄に「 　 」（幅3）を入力した場合、
- **期待結果**: 「作成」は無効になる

### テストケース116: 作成ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、入力欄はそのまま「abcdefghijklmnopqrst」になる [SMP-N02]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、
- **期待結果**: 入力欄はそのまま「abcdefghijklmnopqrst」になる

### テストケース117: 作成ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、入力欄はそのまま「あいうえおかきくけこ」になる [SMP-N02]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、
- **期待結果**: 入力欄はそのまま「あいうえおかきくけこ」になる

### テストケース118: 作成ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、入力欄はそのまま「あいうえおabcdefghij」になる [SMP-N02]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、
- **期待結果**: 入力欄はそのまま「あいうえおabcdefghij」になる

### テストケース119: 作成ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N02]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、
- **期待結果**: 入力欄は「abcdefghijklmnopqrst」のまま

### テストケース120: 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N02]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、
- **期待結果**: 入力欄は「あいうえおかきくけこ」のまま

### テストケース121: 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N02]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、
- **期待結果**: 入力欄は「あいうえおかきくけこ」のまま

### テストケース122: 作成ダイアログの空の入力欄に「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N02]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの空の入力欄に「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの空の入力欄に「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、
- **期待結果**: 入力欄は空のまま

### テストケース123: 作成ダイアログの空の状態で「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N02]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 作成ダイアログの空の状態で「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 作成ダイアログの空の状態で「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、
- **期待結果**: 入力欄は空のまま

### テストケース124: 編集ダイアログの入力欄に「X」（幅1）を入力した場合、「保存」は有効になる [SMP-N03]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄に「X」を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄に「X」を入力した場合、
- **期待結果**: 「保存」は有効になる

### テストケース125: 編集ダイアログの入力欄に「 X 」（幅3）を入力した場合、「保存」は有効になる [SMP-N03]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄に「 X 」を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄に「 X 」を入力した場合、
- **期待結果**: 「保存」は有効になる

### テストケース126: 編集ダイアログの入力欄に「」（空）を入力した場合、「保存」は無効になる [SMP-N03]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄に「」を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄に「」を入力した場合、
- **期待結果**: 「保存」は無効になる

### テストケース127: 編集ダイアログの入力欄に「   」（半角スペース3つ）を入力した場合、「保存」は無効になる [SMP-N03]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄に「   」を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄に「   」を入力した場合、
- **期待結果**: 「保存」は無効になる

### テストケース128: 編集ダイアログの入力欄に「　　」（全角スペース2つ）を入力した場合、「保存」は無効になる [SMP-N03]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄に「　　」を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄に「　　」を入力した場合、
- **期待結果**: 「保存」は無効になる

### テストケース129: 編集ダイアログの入力欄に「 　 」（半角・全角スペースの混在）を入力した場合、「保存」は無効になる [SMP-N03]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄に「 　 」を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄に「 　 」を入力した場合、
- **期待結果**: 「保存」は無効になる

### テストケース130: 編集ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、入力欄はそのまま「abcdefghijklmnopqrst」になる [SMP-N04]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログに「abcdefghijklmnopqrst」（半角20）を入力した場合、
- **期待結果**: 入力欄はそのまま「abcdefghijklmnopqrst」になる

### テストケース131: 編集ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、入力欄はそのまま「あいうえおかきくけこ」になる [SMP-N04]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログに「あいうえおかきくけこ」（全角10）を入力した場合、
- **期待結果**: 入力欄はそのまま「あいうえおかきくけこ」になる

### テストケース132: 編集ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、入力欄はそのまま「あいうえおabcdefghij」になる [SMP-N04]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログに「あいうえおabcdefghij」（全角5＋半角10）を入力した場合、
- **期待結果**: 入力欄はそのまま「あいうえおabcdefghij」になる

### テストケース133: 編集ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、入力欄は「abcdefghijklmnopqrst」のまま [SMP-N04]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログで「abcdefghijklmnopqrst」（半角20）の状態で「u」を足した場合、
- **期待結果**: 入力欄は「abcdefghijklmnopqrst」のまま

### テストケース134: 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N04]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「さ」を足した場合、
- **期待結果**: 入力欄は「あいうえおかきくけこ」のまま

### テストケース135: 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、入力欄は「あいうえおかきくけこ」のまま [SMP-N04]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログで「あいうえおかきくけこ」（全角10）の状態で「a」を足した場合、
- **期待結果**: 入力欄は「あいうえおかきくけこ」のまま

### テストケース136: 編集ダイアログの入力欄を空にしてから「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、入力欄は空のまま [SMP-N04]
- **カテゴリ**: 正常系
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄を空にしてから「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄を空にしてから「 abcdefghijklmnopqrst」（先頭の半角スペース＋半角20）を入力した場合、
- **期待結果**: 入力欄は空のまま

### テストケース137: 編集ダイアログの入力欄を空にしてから「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、入力欄は空のまま [SMP-N04]
- **カテゴリ**: 境界値
- **対象メソッド**: FolderNameLengthFormatter / 入力欄
- **事前条件**: 編集ダイアログの入力欄を空にしてから「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、
- **入力値・テスト条件**: FakeSampleRepository（test/helpers/fake_infrastructure.dart）のスタブ値・Failure キューを条件どおりに設定
- **操作手順**: 編集ダイアログの入力欄を空にしてから「abcdefghijklmnopqrstuvwxyz0123」（半角30）を貼り付けた場合、
- **期待結果**: 入力欄は空のまま

## 対象外

- Page 本体（`lib/presentation/sample/sample_page.dart`）は CLAUDE.md の限定分母（`lib/presentation/**/*_view_model.dart` のみが対象）に含まれないため、行カバレッジはハーネスの合否判定には使われない（表示のみ）。
