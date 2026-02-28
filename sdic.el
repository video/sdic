;; sdic.el --- Program to view dictionary -*- lexical-binding: t -*-

;; Copyright (C) 1998,99 TSUCHIYA Masatoshi <tsuchiya@namazu.org>

;; Author: TSUCHIYA Masatoshi <tsuchiya@namazu.org>
;; Keywords: dictionary

;; SDIC is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; SDIC is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with SDIC; if not, write to the Free Software Foundation,
;; Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


;;; Commentary:

;; 英和/和英辞書を閲覧する目的で作成した major mode です。
;; 利用及び再配布の際は、GNU 一般公用許諾書の適当なバージョンにしたがっ
;; て下さい。

;; 一次配布元
;;    http://namazu.org/~tsuchiya/sdic/


;;; Install:

;; (1) sdic.el, sdicf.el, sdicf-client.el, sdic-compat.el, sdic-gene.el
;;     と stem.el を適当な場所に保存して、必要ならバイトコンパイルして
;;     下さい。
;;
;;
;; (2) sdicf-client.el, sdic-compat.el, sdic-gene.el は辞書を検索する
;;     ためのライブラリです。これらのライブラリのどれかを使って辞書を
;;     検索できるようにして下さい。詳細については、README とそれぞれの
;;     ソースファイルを参照。
;;
;;
;; (3) 使えるようにした辞書のリストを、sdic-eiwa-dictionary-list およ
;;     び sdic-waei-dictionary-list に設定します。例えば、英和辞書
;;     /usr/dict/gene.sdic を sdicf-client.el を使って検索する場合は次
;;     のようになります。
;;
;;         (setq sdic-eiwa-dictionary-list '((sdicf-client "/usr/dict/gene.sdic")))
;;
;;     複数の辞書を同時に検索することも出来ます。
;;
;;         (setq sdic-waei-dictionary-list '((sdicf-client "~/data/jedict.sdic")
;;                                           (sdic-compat "/usr/dict/jgene.dic")))
;;
;;     辞書を利用しない場合は nil を代入して下さい。また、これらの設定
;;     は ~/.emacs などの適切な場所に書き込んで下さい。
;;
;;
;; (4) ~/.emacs に次のようなコードを挿入します。
;;
;;         (autoload 'sdic-describe-word "sdic" "英単語の意味を調べる" t nil)
;;         (global-set-key "\C-cw" 'sdic-describe-word)
;;
;;     好みに合わせて適当にキーバインドは変更して下さい。


;;; Note:

;; 検索結果の表示の仕方や動作を制御する変数があります。詳細については、
;; 下の source を参照して下さい。
;;
;; grep / array などの外部コマンドを利用して辞書検索する場合は、それら
;; の外部コマンドが対応している漢字コードを設定して、辞書もその漢字コー
;; ドに合わせる必要があります。


(require 'sdicf)
(require 'stem)


;;;----------------------------------------------------------------------
;;;             カスタマイズ用変数
;;;----------------------------------------------------------------------

(defgroup sdic nil
  "Program to view English-Japanese/Japanese-English dictionary."
  :group 'applications)

(defcustom sdic-left-margin 2
  "Left margin of contents.
説明文の左側の余白幅"
  :type 'integer
  :group 'sdic)

(defcustom sdic-fill-column (default-value 'fill-column)
  "Right edge of contents.
説明文を整形する幅"
  :type 'integer
  :group 'sdic)

(defcustom sdic-window-height 10
  "Height of window to show entrys and contents.
検索結果表示ウインドウの高さ"
  :type 'integer
  :group 'sdic)

(defcustom sdic-warning-hidden-entry t
  "If non-nil, warning of hidden entries is enable.
nil 以外が設定されている場合、検索結果表示ウインドウに表示しきれなかった情報があれば警告する"
  :type 'boolean
  :group 'sdic)

(defcustom sdic-disable-select-window nil
  "Option to disable to select other window.
検索結果表示ウインドウにカーソルを移動しないようにする場合は nil 以外を設定する"
  :type 'boolean
  :group 'sdic)

(defcustom sdic-face-style 'bold
  "Style of entry.
見出し語を表示するために使う装飾形式"
  :type 'symbol
  :group 'sdic)

(defcustom sdic-face-color nil
  "Color of entry.
見出し語を表示するために使う色"
  :type '(choice (const :tag "なし" nil)
                 (color :tag "色"))
  :group 'sdic)

(defcustom sdic-disable-vi-key nil
  "Option to disable some key.
辞書閲覧に vi ライクのキーを使わない場合は nil 以外を設定する"
  :type 'boolean
  :group 'sdic)

(defcustom sdic-eiwa-dictionary-list nil
  "Options of an English-Japanese dictionary.
英和辞典の検索メソッドのリストを指定する変数
各要素は (バックエンドシンボル ファイルパス) の形式。
例: \='((sdicf-client \"/usr/dict/gene.sdic\"))"
  :type '(repeat (list (choice (const sdicf-client)
                               (const sdic-compat)
                               (const sdic-gene)
                               symbol)
                       file))
  :group 'sdic)

(defcustom sdic-waei-dictionary-list nil
  "Options of a Japanese-English dictionary.
和英辞典の検索メソッドのリストを指定する変数
各要素は (バックエンドシンボル ファイルパス) の形式。
例: \='((sdicf-client \"~/data/jedict.sdic\"))"
  :type '(repeat (list (choice (const sdicf-client)
                               (const sdic-compat)
                               (const sdic-gene)
                               symbol)
                       file))
  :group 'sdic)

(defcustom sdic-default-coding-system 'utf-8
  "Default coding-system for sdic and libraries."
  :type 'coding-system
  :group 'sdic)

(defface sdic-face
  `((t (:inherit ,sdic-face-style
                 ,@(if sdic-face-color `(:foreground ,sdic-face-color) nil))))
  "Face for highlighting headwords in SDIC."
  :group 'sdic)




;;;----------------------------------------------------------------------
;;;             内部変数
;;;----------------------------------------------------------------------

(defvar sdic-english-prep-list '("at" "by" "for" "in" "on" "of" "with" "as" "before" "after")
  "List of English prepositions
英語の前置詞のリスト")

(defvar sdic-english-prep-regexp
  (format "\\(%s\\)\\b" (mapconcat #'regexp-quote sdic-english-prep-list "\\|"))
  "Regexp of Englist prepositions
英語の前置詞とマッチする正規表現")

(defvar sdic-eiwa-symbol-list nil "英和辞典のシンボル")
(defvar sdic-waei-symbol-list nil "和英辞典のシンボル")
(defvar sdic-buffer-start-point nil "検索結果表示バッファの表示開始ポイント")
(defvar sdic-mode-map
  (let ((map (make-keymap)))
    (define-key map " " #'scroll-up)
    (define-key map "b" #'scroll-down)
    (define-key map [backspace] #'scroll-down)
    (define-key map [delete] #'scroll-down)
    (define-key map "\C-?" #'scroll-down)
    (define-key map "n" #'sdic-forward-item)
    (define-key map "\t" #'sdic-forward-item)
    (define-key map "p" #'sdic-backward-item)
    (define-key map "\M-\t" #'sdic-backward-item)
    (define-key map "o" #'sdic-other-window)
    (define-key map "q" #'sdic-close-window)
    (define-key map "Q" #'sdic-exit)
    (define-key map "w" #'sdic-describe-word)
    (define-key map "W" (lambda ()
                          (interactive)
                          (let ((f (sdic-select-search-function)))
                            (sdic-describe-word (sdic-read-from-minibuffer) f))))
    (define-key map "/" (lambda ()
                          (interactive)
                          (sdic-describe-word (sdic-read-from-minibuffer
                                               (concat "/" (sdic-word-at-point))))))
    (define-key map "^" (lambda ()
                          (interactive)
                          (sdic-describe-word (sdic-read-from-minibuffer
                                               (concat (sdic-word-at-point) "*")))))
    (define-key map "$" (lambda ()
                          (interactive)
                          (sdic-describe-word (sdic-read-from-minibuffer
                                               (concat "*" (sdic-word-at-point))))))
    (define-key map "'" (lambda ()
                          (interactive)
                          (sdic-describe-word (sdic-read-from-minibuffer
                                               (concat "'" (sdic-word-at-point) "'")))))
    (define-key map "<" #'sdic-goto-point-min)
    (define-key map ">" #'sdic-goto-point-max)
    (define-key map "?" #'describe-mode)
    map)
  "Keymap of sdic-mode")

(defvar sdic-kinsoku-bol-list
  (string-to-list
   "!)-_~}]:;',.?、。，．・：；？！゛゜´｀¨＾￣＿ヽヾゝゞ〃仝々〆〇ー—‐／＼〜‖｜…‥’”）〕］｝〉》」』】°′″℃ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ")
  "行頭禁則文字のリスト")

(defvar sdic-kinsoku-eol-list
  (string-to-list
   "({[`'“（〔［｛〈《「『【°′″§")
  "行末禁則文字のリスト")

(defvar sdic-kinsoku-spc-list
  (string-to-list "\t 　")
  "空白文字のリスト")

(defconst sdic-version "2.1.3")
(defconst sdic-buffer-name "*sdic*" "検索結果表示バッファの名前")
(defconst sdic-mode-name "SDIC" "検索結果を表示するバッファの major mode")




;;;----------------------------------------------------------------------
;;;             検索メソッドを呼び出す関数
;;;----------------------------------------------------------------------

(defun sdic-init-dictionary (option-list)
  "Function to initialize dictionary.
指定された辞書と関連付けられている検索ライブラリを初期化する関数"
  (let (dic)
    (and option-list
         (listp option-list)
         (require (car option-list))
         (setq dic (apply (get (car option-list) 'init-dictionary) (cdr option-list)))
         (sdic-dictionary-symbol-p dic)
         (put dic 'search-method (car option-list))
         dic)))


(defun sdic-open-dictionary (dic)
  "Function to open dictionary.
指定された辞書を検索できるようにする関数"
  (and (sdic-dictionary-symbol-p dic)
       (funcall (get (get dic 'search-method) 'open-dictionary) dic)))


(defun sdic-close-dictionary (dic)
  "Function to close dictionary.
指定された辞書と関連付けられている検索ライブラリを終了する関数"
  (and (sdic-dictionary-symbol-p dic)
       (funcall (get (get dic 'search-method) 'close-dictionary) dic)))


(defun sdic-search-entry (dic word &optional search-type)
  "Function to search word in dictionary.
指定された辞書を検索する関数
見出し語、辞書シンボル、見出し語のIDからなる配列を要素とする配列を返す。"
  (mapcar (lambda (c)
            (list (car c) dic (cdr c)))
          (funcall (get (get dic 'search-method) 'search-entry) dic word search-type)))


(defun sdic-sort-dictionary-order (entry-list)
  "Function to sort entry list in dictionary order.
見出し語、辞書シンボル、見出し語のIDからなる配列を要素とする配列 
ENTRY-LIST を、見出し語の辞書順に並べ替える関数。"
  (mapcar #'cdr
          (sort (mapcar (lambda (entry)
                          (if (string-match "\\Ca" (car entry))
                              (cons (concat (car entry) " ") entry)
                            (cons (concat (replace-regexp-in-string "[^A-Za-z0-9]+" " " (downcase (car entry)))
                                          " " (car entry) " ")
                                  entry)))
                        entry-list)
                (lambda (a b) (string< (car a) (car b))))))


(defun sdic-search-multi-dictionaries (dic-list word &optional search-type)
  "Function to search word in multi dictionaries.
指定されている複数の辞書を串刺検索する関数
見出し語、辞書シンボル、見出し語のIDからなる配列を要素とする配列を返す。"
  (sdic-sort-dictionary-order
   (apply #'append
          (mapcar (lambda (dic)
                    (sdic-search-entry dic word search-type))
                  dic-list))))


(defun sdic-get-content (dic id)
  "Function to get content.
指定されている辞書から定義文を読み出す関数"
  (funcall (get (get dic 'search-method) 'get-content) dic id))


(defun sdic-make-dictionary-symbol ()
  (make-symbol "sdic-dictionary"))


(defun sdic-dictionary-symbol-p (symbol)
  (equal (symbol-name symbol) "sdic-dictionary"))




;;;----------------------------------------------------------------------
;;;             内部関数
;;;----------------------------------------------------------------------

(defun sdic--content-normalize-commas (content)
  "コンマ直後に空白を挿入した文字列を返す非公開関数。"
  (let ((buf nil) (pos 0))
    (while (string-match ",\([^ ]\)" content pos)
      (setq buf (cons ", " (cons (substring content pos (match-beginning 0)) buf))
            pos (match-beginning 1)))
    (mapconcat #'identity
               (nreverse (if (< pos (length content))
                             (cons (substring content pos) buf)
                           buf))
               "")))


(defun sdic--content-normalize-slashes (content)
  "数字または空白で挟まれないスラッシュの前後に空白を挿入した文字列を返す非公開関数。"
  (let ((buf nil) (pos 0))
    (while (string-match "[^ 0-9]\(/\)[^ 0-9]" content pos)
      (setq buf (cons " / " (cons (substring content pos (match-beginning 1)) buf))
            pos (match-end 1)))
    (mapconcat #'identity
               (nreverse (if (< pos (length content))
                             (cons (substring content pos) buf)
                           buf))
               "")))


(defun sdic--kinsoku-wrap (spc top)
  "禁則処理を考慮しながら fill-column 制限でテキストを折り返す非公開関数。
SPC は継行インデント文字列、TOP は現在行の開始ポイント。"
  (while (if (>= (move-to-column fill-column) fill-column)
             (not (progn
                    (if (memq (preceding-char) sdic-kinsoku-eol-list)
                        ;; 行末禁則: 禁則文字の前に改行を挿入
                        (progn
                          (forward-char -1)
                          (while (memq (preceding-char) sdic-kinsoku-eol-list)
                            (forward-char -1))
                          (insert "\n" spc))
                      ;; 行頭禁則: 禁則文字を越えた位置で折り返す
                      (let ((ch (progn
                                  (while (memq (following-char) sdic-kinsoku-bol-list)
                                    (forward-char))
                                  (following-char))))
                        (if (memq ch sdic-kinsoku-spc-list)
                            ;; 空白の場合: 空白を削除して改行
                            (delete-region (point)
                                           (progn
                                             (forward-char)
                                             (while (memq (following-char) sdic-kinsoku-spc-list)
                                               (forward-char))
                                             (point)))
                          ;; 英単語は語境界、全角はそのまま折り返す
                          (or (> (char-width ch) 1)
                              (re-search-backward "\\<" top t)
                              (end-of-line)))
                        (or (eolp) (insert "\n" spc)))))))
    (setq top (point))))


(defun sdic-insert-content (word content)
  "見出し語と説明文を禁則処理を考慮して整形しながら挿入する。"
  (overlay-put (make-overlay (point) (progn (insert word) (point))) 'face 'sdic-face)
  (let* ((spc (make-string left-margin ?\ ))
         (content (sdic--content-normalize-commas content))
         (content (sdic--content-normalize-slashes content)))
    (insert "\n" spc)
    (let ((top (point)))
      (insert content "\n")
      (forward-char -1)
      (sdic--kinsoku-wrap spc top)
      (forward-char))))


(defun sdic-insert-entry-list (entry-list)
  "見出し語と説明文を整形しながら挿入する"
  (mapc (lambda (entry)
          (sdic-insert-content (car entry) (sdic-get-content (nth 1 entry) (nth 2 entry))))
        entry-list))


;; 検索形式を判別するマクロ
(put 'sdic-decide-query-type 'lisp-indent-function 2)
(defmacro sdic-decide-query-type (dic-list query &rest sexp)
  "QUERY から検索形式を判定して複数の辞書 DIC-LIST を検索するマクロ。
QUERY に検索形式を指定する構造が含まれていない場合は、default の動作として SEXP を評価する。
通常の検索の場合は、検索された見出し語のリストを返す。"
  `(cond
    ;; 検索語が '' で囲まれている場合 -> 完全一致検索
    ((and (eq ?' (string-to-char ,query))
          (equal "'" (substring ,query -1)))
     (sdic-insert-entry-list
      (sdic-search-multi-dictionaries ,dic-list (substring ,query 1 -1) 'lambda)))
    ;; 検索語の先頭に / がある場合 -> 全文検索
    ((eq ?/ (string-to-char ,query))
     (sdic-insert-entry-list
      (sdic-search-multi-dictionaries ,dic-list (substring ,query 1) 0)))
    ;; 検索語の先頭に * がある場合 -> 後方一致検索
    ((eq ?* (string-to-char ,query))
     (sdic-insert-entry-list
      (sdic-search-multi-dictionaries ,dic-list (substring ,query 1) t)))
    ;; 検索語の末尾に * がある場合 -> 前方一致検索
    ((equal "*" (substring ,query -1))
     (sdic-insert-entry-list
      (sdic-search-multi-dictionaries ,dic-list (substring ,query 0 -1))))
    ;; 特に指定がない場合 -> 指定された S 式を評価
    (t
     ,@sexp)))


;; 英和辞典を検索する関数 - サブ関数群
(defun sdic--eiwa-search-irregular (word-list)
  "不規則変化動詞を辞書検索する非公開関数。
WORD-LIST の先頭語が stem:irregular-verb-alist に存在する場合、
全活用形を辞書で検索し (entries orig stem-list) の形式で返す。
該当しない場合は nil を返す。"
  (let (pat)
    (let* ((irr (copy-sequence (assoc (car word-list) stem:irregular-verb-alist)))
           (stem-list (and irr
                           (delq t (mapcar (lambda (w) (or (equal w pat) (setq pat w)))
                                           irr)))))
      (when stem-list
        (let* (orig
               (entries
                (sdic-sort-dictionary-order
                 (apply #'append
                        (mapcar
                         (lambda (word)
                           (let ((regex (format "^\\(%s$\\|%s \\)"
                                                (regexp-quote word)
                                                (regexp-quote word))))
                             (delq nil
                                   (mapcar
                                    (lambda (entry)
                                      (and (string-match regex (car entry))
                                           (or orig (setq orig word))
                                           entry))
                                    (apply #'append
                                           (mapcar (lambda (dic)
                                                     (sdic-search-entry dic word))
                                                   sdic-eiwa-symbol-list))))))
                         stem-list)))))
          (when entries
            (list entries orig stem-list)))))))


(defun sdic--eiwa-search-with-stemming (word-list)
  "stemming を行なって英和辞典を検索する非公開関数。
(entries orig stem-list) の形式で返す。"
  (let* ((stem-list (let ((stem:irregular-verb-alist nil))
                      (stem:stripping-suffix (car word-list))))
         (stem-list (if (> (length (car word-list)) 1)
                        (delq t (mapcar (lambda (w) (or (= (length w) 1) w)) stem-list))
                      stem-list))
         ;; 最長共通接頭辞を求める
         (lcp-pat (let* ((w1 (car stem-list))
                         (w2 (nth (1- (length stem-list)) stem-list))
                         (i (min (length w1) (length w2))))
                    (while (not (string= (substring w1 0 i) (substring w2 0 i)))
                      (setq i (1- i)))
                    (substring w1 0 i)))
         (orig nil)
         ;; Phase 1: 辞書を検索し、どの stem と一致するか記録する
         (raw-entries
          (mapcar (lambda (entry)
                    (let ((str (downcase (car entry))))
                      (and (member str stem-list)
                           (not (member str orig))
                           (setq orig (cons str orig))))
                    entry)
                  (or (and (= (length stem-list) 1)
                           (string= lcp-pat (car word-list))
                           (< (length lcp-pat) 4)
                           (append
                            (sdic-search-multi-dictionaries sdic-eiwa-symbol-list lcp-pat 'lambda)
                            (sdic-search-multi-dictionaries sdic-eiwa-symbol-list (concat lcp-pat " "))))
                      (sdic-search-multi-dictionaries sdic-eiwa-symbol-list lcp-pat))))
         ;; Phase 2: orig に基づいて stem-list・orig・フィルタパターンを確定する
         (filter-pat
          (if orig
              (let ((new-stem-list (copy-sequence orig)))
                (setq orig (if (member (car word-list) orig)
                               (car word-list)
                             (car (sort orig (lambda (a b) (> (length a) (length b)))))))
                (setq stem-list new-stem-list)
                (format "^\\(%s\\)"
                        (mapconcat (lambda (w)
                                     (format "%s$\\|%s " (regexp-quote w) (regexp-quote w)))
                                   new-stem-list "\\|")))
            (progn
              (setq orig lcp-pat)
              (message "Can't find original form of \"%s\"" (car word-list))
              (concat "^" (regexp-quote lcp-pat)))))
         ;; Phase 3: 確定したパターンでエントリをフィルタする
         (entries (delq nil
                        (mapcar (lambda (entry)
                                  (if (string-match filter-pat (car entry)) entry))
                                raw-entries))))
    (list entries orig stem-list)))


(defun sdic--eiwa-build-display-pattern (word-list stem-list orig)
  "検索結果の表示位置を特定するためのパターン文字列を生成する非公開関数。"
  (if (nth 1 word-list)
      (concat "^\\("
              (mapconcat (lambda (w)
                           (format "%s +%s$\\|%s +%s "
                                   (regexp-quote w)
                                   (regexp-quote (nth 1 word-list))
                                   (regexp-quote w)
                                   (regexp-quote (nth 1 word-list))))
                         stem-list "\\|")
              (if (string= orig (car word-list))
                  "\\)"
                (format "\\|%s\\)" (regexp-quote orig))))
    (format "^%s$" (regexp-quote orig))))


(defun sdic--eiwa-find-display-start (point str query)
  "sdic-buffer-start-point を計算して返す非公開関数。
POINT は最初にパターンが一致した位置、STR はそのエントリの見出し語、
QUERY は元の検索語。"
  (if point
      (let* ((orig (car (split-string query nil t)))
             (p (regexp-quote orig)))
        (if (and (not (string= str orig))
                 (string= orig (downcase orig))
                 (let ((case-fold-search nil))
                   (goto-char point)
                   (search-forward-regexp (format "^\\(%s \\|%s$\\)" p p) nil t)))
            (match-beginning 0)
          point))
    (point-min)))


;; 英和辞典を検索する関数
(defun sdic-search-eiwa-dictionary (query)
  "QUERY で英和辞典を検索し、結果をバッファに挿入する。"
  (sdic-decide-query-type sdic-eiwa-symbol-list query
    (let* ((word-list (split-string (downcase query) nil t))
           (result    (or (sdic--eiwa-search-irregular word-list)
                          (sdic--eiwa-search-with-stemming word-list)))
           (entries   (nth 0 result))
           (orig      (nth 1 result))
           (stem-list (nth 2 result))
           (pat       (sdic--eiwa-build-display-pattern word-list stem-list orig))
           point str)
      (prog1
          (mapcar (lambda (entry)
                    (and (not point)
                         (string-match pat (car entry))
                         (setq point (point)
                               str (car entry)))
                    (sdic-insert-content (car entry)
                                         (sdic-get-content (nth 1 entry) (nth 2 entry)))
                    (car entry))
                  entries)
        (setq sdic-buffer-start-point
              (sdic--eiwa-find-display-start point str query))))))


;; 和英辞典を検索する関数
(defun sdic-search-waei-dictionary (query)
  (sdic-decide-query-type sdic-waei-symbol-list query
    ;; 特に指定がない場合 -> 前方一致検索
    (sdic-insert-entry-list
     (sdic-search-multi-dictionaries sdic-waei-symbol-list query))))




;;;----------------------------------------------------------------------
;;;             本体
;;;----------------------------------------------------------------------

(defun sdic-version ()
  "SDIC のバージョンを返す関数"
  (interactive)
  (message "SDIC %s" sdic-version))


(defun sdic-word-at-point ()
  "カーソル位置の単語を返す関数"
  (save-excursion
    (unless (looking-at "\\<") (forward-word -1))
    (if (looking-at sdic-english-prep-regexp)
        (let ((strs
               (split-string
                (buffer-substring-no-properties
                 (progn (forward-word -1) (point)) (progn (forward-word 2) (point)))
                nil t)))
          (if (string-match "\\cj" (car strs))
              (car (cdr strs))
            (concat (car strs) " " (car (cdr strs)))))
      (buffer-substring-no-properties (point) (progn (forward-word 1) (point))))))


(defvar sdic-read-minibuffer-history '()
  "sdic-read-from-minibuffer 関数のヒストリ")
(defun sdic-read-from-minibuffer (&optional init pre-prompt)
  "ミニバッファから単語を読みとる"
  (let ((w (or init (sdic-word-at-point) "")))
    (setq sdic-read-minibuffer-history (cons w sdic-read-minibuffer-history)
          w (read-from-minibuffer (if pre-prompt
                                      (format "%s Input word : " pre-prompt)
                                    "Input word : ")
                                  w nil nil '(sdic-read-minibuffer-history . 1)))
    (while (< (length w) 2)
      (setq w (read-from-minibuffer
               (format "\"%s\" is too short. Input word again : " w)
               w nil nil '(sdic-read-minibuffer-history . 1))))
    w))


(defun sdic-select-search-function ()
  "検索関数を選ぶ"
  (message "辞書を選んで下さい: E)英和 J)和英")
  (let ((sw (selected-window))
        result)
    (while (not result)
      (let ((c (read-char)))
        (cond
         ((or (= c ?e) (= c ?E)) (setq result 'sdic-search-eiwa-dictionary))
         ((or (= c ?j) (= c ?J)) (setq result 'sdic-search-waei-dictionary)))))
    (select-window sw)
    result))


;; 単語を辞書で調べる関数
(defun sdic-describe-word (word &optional search-function)
  "Display the meaning of word."
  (interactive
   (let ((f (if current-prefix-arg (sdic-select-search-function)))
         (w (sdic-read-from-minibuffer)))
     (list w f)))
  (with-current-buffer (get-buffer-create sdic-buffer-name)
    (or (string= mode-name sdic-mode-name) (sdic-mode))
    (setq buffer-read-only nil)
    (erase-buffer)
    (let ((case-fold-search t)
          (sdic-buffer-start-point (point-min)))
      (if (prog1 (funcall (or search-function
                              (if (string-match "\\cj" word)
                                  'sdic-search-waei-dictionary
                                'sdic-search-eiwa-dictionary))
                          word)
            (setq buffer-read-only t)
            (set-buffer-modified-p nil))
          (sdic-display-buffer sdic-buffer-start-point)
        (message "Can't find word, \"%s\"." word)
        nil))))


;; 主関数の宣言
(defalias 'sdic 'sdic-describe-word)


(defun sdic-describe-region (start end &optional search-function)
  "Display the meaning of pattern."
  (interactive
   (list (region-beginning)
         (region-end)
         (if current-prefix-arg (sdic-select-search-function))))
  (sdic-describe-word (buffer-substring start end) search-function))


(defun sdic-describe-word-at-point (&optional search-function)
  "Display the meaning of word at point in Japanese."
  (interactive (list (if current-prefix-arg (sdic-select-search-function))))
  (let ((orig-table (syntax-table))
        word)
    (unwind-protect
        (progn
          (set-syntax-table (let ((table (copy-syntax-table)))
                              (modify-syntax-entry ?* "w" table)
                              (modify-syntax-entry ?' "w" table)
                              (modify-syntax-entry ?/ "w" table)
                              table))
          (setq word (or (sdic-word-at-point) (sdic-read-from-minibuffer))))
      (set-syntax-table orig-table))
    (or (sdic-describe-word word search-function)
        (sdic-describe-word (sdic-read-from-minibuffer word (format "Can't find word \"%s\"." word))
                            search-function))))


;;; 次の項目に移動する関数
(defun sdic-forward-item ()
  "Move point to the next item."
  (interactive)
  (let ((o))
    (goto-char (next-overlay-change
                (if (setq o (car (overlays-at (point))))
                    (overlay-end o)
                  (point))))))


;;; 前の項目に移動する関数
(defun sdic-backward-item ()
  "Move point to the previous item."
  (interactive)
  (let ((o))
    (goto-char (previous-overlay-change
                (previous-overlay-change
                 (if (setq o (car (overlays-at (point))))
                     (overlay-start o)
                   (previous-overlay-change (previous-overlay-change (point)))))))))


(defun sdic-goto-point-min ()
  "バッファの先頭に移動する関数"
  (interactive)
  (goto-char (point-min)))


(defun sdic-goto-point-max ()
  "バッファの末尾に移動する関数"
  (interactive)
  (goto-char (point-max)))


(defun sdic-display-buffer (&optional start-point)
  "検索結果表示バッファを表示する関数"
  (let ((old-buffer (current-buffer)))
    (unwind-protect
        (let* ((buf (set-buffer sdic-buffer-name))
               (w1 (selected-window))
               (w2 (get-buffer-window buf))
               (p (or start-point (point)))
               (h sdic-window-height))
          (if w2 (progn (select-window w2) (setq h (window-height w2)))
            (setq w2 (select-window (if (one-window-p)
                                        (split-window w1 (- (window-height) h))
                                      (next-window))))
            (set-window-buffer w2 buf))
          (with-selected-window w2
            (goto-char p)
            (recenter 0))
          (and sdic-warning-hidden-entry
               (> p (point-min))
               (message "この前にもエントリがあります。"))
          (if sdic-disable-select-window (select-window w1))
          (buffer-size))
      (set-buffer old-buffer))))


(defun sdic-other-window ()
  "検索表示バッファから元のバッファに戻る関数"
  (interactive)
  (let ((w (selected-window)))
    (if (and (string= (buffer-name (window-buffer w))
                      sdic-buffer-name)
             (one-window-p))
        (progn
          (split-window w (- (window-height) sdic-window-height))
          (set-window-buffer w (other-buffer)))
      (other-window -1))))


(defun sdic-close-window ()
  "検索表示バッファを表示しているウインドウを消去する関数"
  (interactive)
  (let ((w (get-buffer-window sdic-buffer-name))
        (b (get-buffer sdic-buffer-name)))
    (if w
        (progn
          (bury-buffer b)
          (if (= (window-height w) sdic-window-height)
              (delete-window w)
            (set-window-buffer w (other-buffer))
            (select-window (next-window)))
          ))))


(defun sdic-close-all-dictionary ()
  "開いている辞書をすべて閉じる"
  (mapc 'sdic-close-dictionary sdic-eiwa-symbol-list)
  (mapc 'sdic-close-dictionary sdic-waei-symbol-list)
  (setq sdic-eiwa-symbol-list nil
        sdic-waei-symbol-list nil))


(defun sdic-exit ()
  "検索結果表示バッファを削除する関数"
  (interactive)
  (if (buffer-live-p (get-buffer sdic-buffer-name))
      (progn
        (sdic-close-window)
        (kill-buffer sdic-buffer-name)))
  (sdic-close-all-dictionary))


;;; 辞書を閲覧する major-mode
(define-derived-mode sdic-mode special-mode "SDIC"
  "辞書を閲覧するメジャーモード。

次のような形式の文字列を入力することによって検索方式を指定できます。

\\='word\\='          完全一致検索
word*           前方一致検索
*word           後方一致検索
/word           全文検索

これら以外の場合は、通常のキーワード検索を行います。


key             binding
---             -------

w               単語を検索する
'               完全一致検索をする
^               前方一致検索をする
$               後方一致検索をする
/               全文検索をする
W               辞書を指定して検索する
SPC             スクロールアップ
b               スクロールダウン ( BS / Delete キーも使えます )
n               次の項目
TAB             次の項目
p               前の項目
M-TAB           前の項目
o               辞書を閲覧しているウインドウから他のウインドウに移る
q               辞書を閲覧しているウインドウを消す
Q               SDIC を終了する
<               バッファの先頭に移動
>               バッファの終端に移動
?               ヘルプ表示"
  (make-local-variable 'fill-column)
  (make-local-variable 'left-margin)
  (setq fill-column sdic-fill-column
        left-margin sdic-left-margin)
  (use-local-map sdic-mode-map)
  ;; vi キーバインドの追加設定
  (unless sdic-disable-vi-key
    (define-key sdic-mode-map "h" #'backward-char)
    (define-key sdic-mode-map "j" #'next-line)
    (define-key sdic-mode-map "k" #'previous-line)
    (define-key sdic-mode-map "l" #'forward-char))
  ;; それぞれの辞書を初期化する
  (or sdic-eiwa-symbol-list
      (setq sdic-eiwa-symbol-list
            (delq nil (mapcar #'sdic-init-dictionary sdic-eiwa-dictionary-list))))
  (setq sdic-eiwa-symbol-list (delq nil (mapcar #'sdic-open-dictionary sdic-eiwa-symbol-list)))
  (or sdic-waei-symbol-list
      (setq sdic-waei-symbol-list
            (delq nil (mapcar #'sdic-init-dictionary sdic-waei-dictionary-list))))
  (setq sdic-waei-symbol-list (delq nil (mapcar #'sdic-open-dictionary sdic-waei-symbol-list))))


(provide 'sdic)

;;; sdic.el ends here
