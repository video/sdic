;; sdic-compat.el --- Library to search COMPAT format dictionary -*- lexical-binding: t -*-

;; Copyright (C) 1998,99 TSUCHIYA Masatoshi <tsuchiya@namazu.org>

;; Author: TSUCHIYA Masatoshi <tsuchiya@namazu.org>
;; Keywords: dictionary

;; This file is part of SDIC.

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

;; COMPAT 形式の辞書を外部プログラム( look / grep )を利用して検索する
;; ライブラリです。COMPAT 形式の詳細については sdic.texi を参照して下
;; さい。


;;; Install:

;; (1) look と大文字/小文字の違いを無視した検索が出来る grep が必要です。
;;     パスが通っているか確認して下さい。look が無い環境では sdic-compat
;;     は利用できません。代わりに sdicf-client または sdic-gene を使って
;;     下さい。
;;
;; (2) 辞書を適切な形式に変換して、適当な場所( 例: /usr/dict/ )に保存
;;     して下さい。辞書変換用スクリプトとして以下の Perl スクリプトが
;;     利用できます。
;;
;;         gene.perl    - GENE95 辞書
;;         jgene.perl   - GENE95 辞書から和英辞書を生成する
;;         eijirou.perl - 英辞郎
;;
;;     --compat オプションを指定する必要があります。
;;
;; (3) 使えるようにした辞書の定義情報を sdic-eiwa-dictionary-list また
;;     は sdic-waei-dictionary-list に追加して下さい。
;;
;;         (setq sdic-eiwa-dictionary-list
;;               (cons '(sdic-compat "/usr/dict/gene.dic") sdic-eiwa-dictionary-list))
;;
;;     辞書定義情報は次のような構成になっています。
;;
;;         (sdic-compat ファイル名 (オプションA 値A) (オプションB 値B) ...)
;;
;;     特別な指定が不要な場合には、オプションは省略できます。
;;
;;         (sdic-compat ファイル名)


;;; Options:

;; sdic-compat.el に対して指定できるオプションは次の通りです。
;;
;; coding-system
;;     辞書の漢字コードを指定します。省略した場合は、
;;     sdic-default-coding-system の値を使います。
;;
;; title
;;     辞書のタイトルを指定します。省略した場合は、辞書ファイルの 
;;     basename をタイトルとします。
;;
;; look
;;     前方一致検索/完全一致検索の時に利用する外部コマンドの名前を指定
;;     します。省略した場合は sdic-compat-look-command の値を使います。
;;
;; look-case-option
;;     look オプションによって指定された外部コマンドに対して、英大文字
;;     /小文字を区別しないで検索するように指示するためのコマンドライン
;;     引数を指定します。省略した場合は sdic-compat-look-case-option の
;;     値を使います。
;;
;; grep
;;     後方一致検索/全文検索/正規表現検索の時に利用する外部コマンドの
;;     名前を指定します。省略した場合は sdic-compat-grep-command の値
;;     を使います。
;;
;; grep-case-option
;;     grep オプションによって指定された外部コマンドに対して、英大文字
;;     /小文字を区別しないで検索するように指示するためのコマンドライン
;;     引数を指定します。省略した場合は sdic-compat-grep-case-option の
;;     値を使います。
;;
;; grep-fixed-option
;;     grep オプションによって指定された外部コマンドに対して、固定文字
;;     列として検索するように指示するためのコマンドライン引数を指定します。
;;     省略した場合は sdic-compat-grep-fixed-option の値を使います。
;;
;; grep-regexp-option
;;     grep オプションによって指定された外部コマンドに対して、拡張正規
;;     表現として検索するように指示するためのコマンドライン引数を指定し
;;     ます。省略した場合は sdic-compat-grep-regexp-option の値を使います。


;;; Note:

;; sdic-compat-look-command / sdic-compat-grep-command の値は自動的に
;; 設定されます。以前のバージョンでは fgrep や egrep も検索していま
;; したが、現在は grep に一本化され、オプションによって検索種別を
;; 切り替えるようになっています。
;;
;; sdic-compat.el と sdic-gene.el は同じ機能を提供しているライブラリで
;; す。sdic-compat.el は外部コマンドを呼び出しているのに対して、
;; sdic-gene.el は Emacs の機能のみを利用しています。ただし、辞書をバッ
;; ファに読み込んでから検索を行なうので、大量のメモリが必要になります。
;;
;; Default の設定では、必要な外部コマンドが見つかった場合は 
;; sdic-compat.el を、見つからなかった場合には sdic-gene.el を使うよう
;; になっています。


;;; ライブラリ定義情報
(require 'sdic)
(require 'sdicf)

(put 'sdic-compat 'version "2.0")
(put 'sdic-compat 'init-dictionary 'sdic-compat-init-dictionary)
(put 'sdic-compat 'open-dictionary 'sdic-compat-open-dictionary)
(put 'sdic-compat 'close-dictionary 'sdic-compat-close-dictionary)
(put 'sdic-compat 'search-entry 'sdic-compat-search-entry)
(put 'sdic-compat 'get-content 'sdic-compat-get-content)


;;;----------------------------------------------------------------------
;;;             定数/変数の宣言
;;;----------------------------------------------------------------------

(defvar sdic-compat-look-command (sdicf-find-program "look")
  "Executable file name of look")

(defvar sdic-compat-look-case-option "-f" "Command line option for look to ignore case")

(defvar sdic-compat-grep-command (sdicf-find-program "grep")
  "Executable file name of grep")

(defvar sdic-compat-grep-case-option "-i" "Command line option for grep to ignore case")

(defvar sdic-compat-grep-fixed-option "-F" "Command line option for grep to specify fixed strings")

(defvar sdic-compat-grep-regexp-option "-E" "Command line option for grep to specify extended regular expression")

(defconst sdic-compat-search-buffer-name " *sdic-compat*")



;;;----------------------------------------------------------------------
;;;             本体
;;;----------------------------------------------------------------------

(defun sdic-compat-init-dictionary (file-name &rest option-list)
  "Function to initialize dictionary"
  (let ((dic (sdic-make-dictionary-symbol)))
    (if (file-readable-p (setq file-name (expand-file-name file-name)))
        (progn
          (mapc (lambda (c) (put dic (car c) (nth 1 c))) option-list)
          (put dic 'file-name file-name)
          (put dic 'identifier (concat "sdic-compat+" file-name))
          (or (get dic 'title)
              (put dic 'title (file-name-nondirectory file-name)))
          (or (get dic 'look)
              (put dic 'look sdic-compat-look-command))
          (or (get dic 'look-case-option)
              (put dic 'look-case-option sdic-compat-look-case-option))
          (or (get dic 'grep)
              (put dic 'grep sdic-compat-grep-command))
          (or (get dic 'grep-case-option)
              (put dic 'grep-case-option sdic-compat-grep-case-option))
          (or (get dic 'grep-fixed-option)
              (put dic 'grep-fixed-option sdic-compat-grep-fixed-option))
          (or (get dic 'grep-regexp-option)
              (put dic 'grep-regexp-option sdic-compat-grep-regexp-option))
          (or (get dic 'coding-system)
              (put dic 'coding-system sdic-default-coding-system))
          (and (stringp (get dic 'look))
               (stringp (get dic 'grep))
               dic))
      (error "Can't read dictionary: %s" (prin1-to-string file-name)))))


(defun sdic-compat-open-dictionary (dic)
  "Function to open dictionary"
  (and (or (buffer-live-p (get dic 'sdic-compat-search-buffer))
           (put dic 'sdic-compat-search-buffer (generate-new-buffer sdic-compat-search-buffer-name)))
       dic))


(defun sdic-compat-close-dictionary (dic)
  "Function to close dictionary"
  (when (buffer-live-p (get dic 'sdic-compat-search-buffer))
    (kill-buffer (get dic 'sdic-compat-search-buffer)))
  (put dic 'sdic-compat-search-buffer nil))


(defun sdic-compat-search-entry (dic string &optional search-type)
  "look または grep を使って検索する。結果は専用の検索バッファに保持される。
search-type の値によって次のように動作を変更する。
    nil    : 前方一致検索
    t      : 後方一致検索
    lambda : 完全一致検索
    0      : 全文検索
    regexp : 正規表現検索
検索結果として見つかった見出し語をキーとし、その定義文の先頭位置を値とする
連想リストを返す。"
  (let ((max-count (sdicf--normalize-max-count
                    sdic-search-max-count
                    'sdic-search-max-count)))
    (when (zerop (or max-count 1))
      (cl-return-from sdic-compat-search-entry nil))
    (with-current-buffer (get dic 'sdic-compat-search-buffer)
      (save-excursion
        (save-restriction
          (if (get dic 'sdic-compat-erase-buffer)
              (let ((inhibit-read-only t)) (erase-buffer))
            (goto-char (point-max))
            (narrow-to-region (point-max) (point-max)))
          (put dic 'sdic-compat-erase-buffer nil)
          (let ((filename (get dic 'file-name))
                (coding (get dic 'coding-system))
                (l-case-opt (get dic 'look-case-option))
                (g-case-opt (get dic 'grep-case-option))
                (g-fixed-opt (get dic 'grep-fixed-option))
                (g-regexp-opt (get dic 'grep-regexp-option))
                (is-non-ascii (string-match "\\Ca" string)))
            (cond
             ;; 前方一致検索の場合 -> look を使って検索
             ((eq search-type nil)
              (if is-non-ascii
                  (sdicf-call-process (get dic 'look) coding nil t nil
                                      string filename)
                (sdicf-call-process (get dic 'look) coding nil t nil
                                    l-case-opt string filename)))
             ;; 後方一致検索の場合 -> grep を使って検索
             ((eq search-type t)
              (let ((args (append
                           (sdicf--max-count-option max-count)
                           (if is-non-ascii nil (list g-case-opt))
                           (if g-fixed-opt (list g-fixed-opt))
                           (list (concat string "\t") filename))))
                (apply #'sdicf-call-process (get dic 'grep) coding nil t nil args)))
             ;; 完全一致検索の場合 -> look を使って検索 / 余分なデータを消去
             ((eq search-type 'lambda)
              (if is-non-ascii
                  (sdicf-call-process (get dic 'look) coding nil t nil
                                      string filename)
                (sdicf-call-process (get dic 'look) coding nil t nil
                                    l-case-opt string filename))
              (goto-char (point-min))
              (while (if (looking-at (format "%s\t" (regexp-quote string)))
                         (= 0 (forward-line 1))
                       (delete-region (point) (point-max)))))
             ;; 全文検索の場合 -> grep を使って検索
             ((eq search-type 0)
              (let ((args (append
                           (sdicf--max-count-option max-count)
                           (if is-non-ascii nil (list g-case-opt))
                           (if g-fixed-opt (list g-fixed-opt))
                           (list string filename))))
                (apply #'sdicf-call-process (get dic 'grep) coding nil t nil args)))
             ;; 正規表現検索の場合 -> 拡張正規表現を有効にした grep を使って検索
             ((eq search-type 'regexp)
              (or (stringp (get dic 'grep))
                  (error "%s" "Command to search regular expression pattern is not specified"))
              (let ((args (append
                           (sdicf--max-count-option max-count)
                           (if is-non-ascii nil (list g-case-opt))
                           (if g-regexp-opt (list g-regexp-opt))
                           (list string filename))))
                (apply #'sdicf-call-process (get dic 'grep) coding nil t nil args)))
             ;; それ以外の検索形式を指定された場合
             (t
              (error "Not supported search type is specified. (%s)"
                     (prin1-to-string search-type)))))
          ;; 各検索結果に ID を付与する
          (goto-char (point-min))
          (let (ret)
            (while (if (looking-at "\\([^\t]+\\)\t")
                       (progn
                         (setq ret (cons (cons (match-string 1) (match-end 0)) ret))
                         (= 0 (forward-line 1)))))
            (nreverse ret)))))))


(defun sdic-compat-get-content (dic point)
  (with-current-buffer (get dic 'sdic-compat-search-buffer)
    (save-excursion
      (put dic 'sdic-compat-erase-buffer t)
      (if (<= point (point-max))
          (buffer-substring (goto-char point) (progn (end-of-line) (point)))
        (error "Can't find content. (ID=%d)" point)))))


(provide 'sdic-compat)

;;; sdic-compat.el ends here
