;; sdicf.el --- Search library for SDIC format dictionary -*- lexical-binding: t -*-

;; Copyright (C) 1999 TSUCHIYA Masatoshi <tsuchiya@namazu.org>

;; Author: TSUCHIYA Masatoshi <tsuchiya@namazu.org>
;;         NISHIDA Keisuke <knishida@ring.aist.go.jp>
;; Created: 1 Feb 1999
;; Version: 0.9
;; Keywords: dictionary

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


;;; Commentary:

;; これは、SDIC形式辞書を検索するためのライブラリです。次の関数から成
;; ります。

;;     sdicf-open           - SDIC 辞書のオープン
;;     sdicf-close          - SDIC 辞書のクローズ
;;     sdicf-search         - SDIC 辞書から検索
;;     sdicf-entry-headword - エントリの見出し語を得る
;;     sdicf-entry-keywords - エントリの検索キーのリストを得る
;;     sdicf-entry-text     - エントリの本文を得る

;; それぞれの関数の詳細は、関数の説明文字列に記述されています。


;;; Note:

;; * `auto-compression-mode' を有効にすることで、`direct' 方式で圧縮
;;   した辞書を用いることが出来る。展開は自動で行なわれるため、特別な
;;   設定は必要ありません。
;; 
;; * 速度重視のため `save-match-data' による一致データの退避と回復は一
;;   切していません。


(require 'cl-lib)


;;;------------------------------------------------------------
;;;             Customizable variables
;;;------------------------------------------------------------

(defun sdicf-find-program (&rest programs)
  "指定されたプログラムリストの中から、最初に実行可能なものを返す。"
  (let (ret)
    (while (and programs (not ret))
      (setq ret (executable-find (car programs))
            programs (cdr programs)))
    ret))

(defvar sdicf-default-directory (expand-file-name "~/")
  "Default directory for executing command.")

(defvar sdicf-grep-command (sdicf-find-program "rg" "grep")
  "Executable file name of grep")

(defvar sdicf-grep-max-count 2000
  "Max count of search result for rg/grep.
If nil, do not limit search result.")

(defvar sdicf-array-command (sdicf-find-program "sary")
  "Executable file name of sary.")

(defvar sdicf-array-max-count 2000
  "Max count of search result for sary.
If nil, do not limit search result.")

(defvar sdicf-default-coding-system 'utf-8
  "Default coding system for sdicf.el")

;; Error Symbols
(put 'sdicf-missing-file 'error-conditions '(error sdicf-errors sdicf-missing-file))
(put 'sdicf-missing-file 'error-message "Can't find file")
(put 'sdicf-missing-executable 'error-conditions '(error sdicf-errors sdicf-missing-executable))
(put 'sdicf-missing-executable 'error-message "Can't find executable")
(put 'sdicf-invalid-strategy 'error-conditions '(error sdicf-errors sdicf-invalid-strategy))
(put 'sdicf-invalid-strategy 'error-message "Invalid search strategy")
(put 'sdicf-decide-strategy 'error-conditions '(error sdicf-errors sdicf-decide-strategy))
(put 'sdicf-decide-strategy 'error-message "Can't decide strategy automatically")
(put 'sdicf-invalid-method 'error-conditions '(error sdicf-errors sdicf-invalid-method))
(put 'sdicf-invalid-method 'error-message "Invalid search method")



;;;------------------------------------------------------------
;;;             Internal variables
;;;------------------------------------------------------------

(defconst sdicf-version "0.9" "Version number of sdicf.el")

(defconst sdicf-strategy-alist
  '((array sdicf-array-available sdicf-array-init sdicf-array-quit sdicf-array-search)
    (grep sdicf-grep-available sdicf-grep-init sdicf-grep-quit sdicf-grep-search)
    (direct sdicf-direct-available sdicf-direct-init sdicf-direct-quit sdicf-direct-search))
  "利用できる strategy の連想配列
配列の各要素は、
    strategy のシンボル
    strategy の利用可能性を検査する関数
    strategy を初期化する関数
    strategy を終了する関数
    strategy を使って検索する関数
の4つの要素からなるリストとなっている。strategy の自動判定を行うときは、
この連想配列に先に登録されている strategy が使われる。")



;;;------------------------------------------------------------
;;;             Internal functions
;;;------------------------------------------------------------

(defsubst sdicf-object-p (sdic)
  "辞書オブジェクトかどうか検査する"
  (and (vectorp sdic) (eq 'SDIC (aref sdic 0))))

(defsubst sdicf-entry-p (entry)
  (and (stringp entry) (string-match "^<.>\\([^<]+\\)</.>" entry)))

(defsubst sdicf-get-filename (sdic)
  "辞書オブジェクトからファイル名を得る"
  (aref sdic 1))

(defsubst sdicf-get-coding-system (sdic)
  "辞書オブジェクトから coding-system を得る"
  (aref sdic 2))

(defsubst sdicf-get-strategy (sdic)
  "辞書オブジェクトから strategy を得る"
  (aref sdic 3))

(defsubst sdicf-get-buffer (sdic)
  "辞書オブジェクトから検索用バッファを得る"
  (aref sdic 4))

(defun sdicf-common-init (sdic)
  "共通の辞書初期化関数
作業用バッファが存在することを確認し、なければ新しく生成する。作業用バッファを返す。"
  (or (and (buffer-live-p (sdicf-get-buffer sdic))
           (sdicf-get-buffer sdic))
      (let ((buf (generate-new-buffer (format " *sdic %s*" (sdicf-get-filename sdic)))))
        (buffer-disable-undo buf)
        (aset sdic 4 buf))))

(defun sdicf-common-quit (sdic)
  "共通の辞書終了関数。"
  (if (buffer-live-p (sdicf-get-buffer sdic)) (kill-buffer (sdicf-get-buffer sdic))))

(defun sdicf-encode-string (string)
  "STRING をエンコードする。エンコードした文字列を返す。"
  (let ((start 0) ch list)
    (while (string-match "[&<>\n]" string start)
      (setq ch (aref string (match-beginning 0))
            list (cons (if (eq ch ?&) "&amp;"
                         (if (eq ch ?<) "&lt;"
                           (if (eq ch ?>) "&gt;" "&lf;")))
                       (cons (substring string start (match-beginning 0)) list))
            start (match-end 0)))
    (mapconcat #'identity (nreverse (cons (substring string start) list)) "")))

(defun sdicf-decode-string (string)
  "STRING をデコードする。デコードした文字列を返す。"
  (let ((start 0) list)
    (while (string-match "&\\(\\(lt\\)\\|\\(gt\\)\\|\\(lf\\)\\|\\(amp\\)\\);" string start)
      (setq list (cons (if (match-beginning 2) "<"
                         (if (match-beginning 3) ">"
                           (if (match-beginning 4) "\n" "&")))
                       (cons (substring string start (match-beginning 0)) list))
            start (match-end 0)))
    (mapconcat #'identity (nreverse (cons (substring string start) list)) "")))

(defun sdicf-insert-file-contents (filename coding-system &optional visit beg end replace)
  "CODING-SYSTEM を明示的に指定して insert-file-contents を呼び出す。
CODING-SYSTEM 以外の引数の意味は insert-file-contents と同じ。"
  (let ((coding-system-for-read coding-system))
    (insert-file-contents filename visit beg end replace)))

(defun sdicf-call-process (program coding-system &optional infile buffer display &rest args)
  "CODING-SYSTEM を明示的に指定して call-process を呼び出す。
CODING-SYSTEM 以外の引数の意味は call-process と同じ。"
  (let ((default-directory sdicf-default-directory)
        (coding-system-for-read coding-system)
        (coding-system-for-write coding-system)
        (file-name-coding-system coding-system)
        (default-process-coding-system (cons coding-system coding-system)))
    (apply #'call-process program infile buffer display args)))

(defun sdicf-call-process-region (start end program coding-system &optional buffer display &rest args)
  "CODING-SYSTEM を明示的に指定して call-process-region を呼び出す。
CODING-SYSTEM 以外の引数の意味は call-process-region と同じ。"
  (let ((default-directory sdicf-default-directory)
        (coding-system-for-read coding-system)
        (coding-system-for-write coding-system)
        (file-name-coding-system coding-system)
        (default-process-coding-system (cons coding-system coding-system)))
    (apply #'call-process-region start end program nil buffer display args)))

(defun sdicf-collect-entry-lines (&optional buffer)
  "BUFFER にある SDIC エントリ行のリストを返す。"
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let (entries)
        (while (not (eobp))
          (if (eq (following-char) ?<)
              (progn
                (setq entries
                      (cons (buffer-substring (point)
                                              (progn (end-of-line) (point)))
                            entries))
                (forward-char))
            (forward-line)))
        (nreverse entries)))))

(defun sdicf-search-case-fold-p (method)
  "METHOD に対応する大文字小文字の扱いを返す。
この関数は、呼び出し時のコンテキストにおける `case-fold-search' の値を
動的スコープで参照する。"
  (cond
   ((or (eq method 'text) (eq method 'regexp)) case-fold-search)
   ((or (eq method 'prefix) (eq method 'suffix) (eq method 'exact)) nil)
   (t
    (signal 'sdicf-invalid-method (list method)))))



;;; Strategy `direct'

(defun sdicf-direct-available (sdic)
  (or (file-readable-p (sdicf-get-filename sdic))
      (signal 'sdicf-missing-file (list (sdicf-get-filename sdic)))))

(defun sdicf-direct-init (sdic)
  (or (buffer-live-p (sdicf-get-buffer sdic))
      (save-excursion
        (sdicf-common-init sdic)
        (with-current-buffer (sdicf-get-buffer sdic)
          (let ((inhibit-read-only t)) (erase-buffer))
          (sdicf-insert-file-contents (sdicf-get-filename sdic) (sdicf-get-coding-system sdic))
          (while (re-search-forward "^#" nil t)
            (delete-region (1- (point)) (progn (end-of-line) (min (1+ (point)) (point-max)))))
          (setq buffer-read-only t)
          (set-buffer-modified-p nil))
        t)))

(defalias 'sdicf-direct-quit 'sdicf-common-quit)

(defun sdicf-direct-search (sdic pattern &optional case regexp)
  "検索対象のファイルをバッファに読み込んで検索を行う。

見つかったエントリのリストを返す。CASE が nil ならば、大文字小文字の違い
を区別して検索する。REGEXP が Non-nil ならば、PATTERN を正規表現と見なして検索する。"
  (sdicf-direct-init sdic)
  (with-current-buffer (sdicf-get-buffer sdic)
    (save-excursion
      (let ((case-fold-search case) entries)
        (goto-char (point-min))
        (if regexp
            (while (re-search-forward pattern nil t)
              (forward-line 0)
              (if (eq (following-char) ?<)
                  (progn
                    (setq entries (cons (buffer-substring (point) (progn (end-of-line) (point))) entries))
                    (forward-char))
                (forward-line)))
          (while (search-forward pattern nil t)
            (forward-line 0)
            (if (eq (following-char) ?<)
                (progn
                  (setq entries (cons (buffer-substring (point) (progn (end-of-line) (point))) entries))
                  (forward-char))
              (forward-line))))
        (nreverse entries)))))



;;; Strategy `grep'

(defun sdicf-grep-available (sdic)
  (and (or (file-readable-p (sdicf-get-filename sdic))
           (signal 'sdicf-missing-file (list (sdicf-get-filename sdic))))
       (or (and (stringp sdicf-grep-command)
                (executable-find sdicf-grep-command))
           (signal 'sdicf-missing-executable '(grep)))))

(defalias 'sdicf-grep-init 'sdicf-common-init)

(defalias 'sdicf-grep-quit 'sdicf-common-quit)

(defun sdicf-grep-search (sdic pattern &optional case regexp)
  "rg または grep を使って検索を行う。

見つかったエントリのリストを返す。CASE が nil ならば、大文字小文字の違い
を区別して検索する。REGEXP が Non-nil ならば正規表現検索(-Eオプション等)を
使って検索する。"
  (sdicf-grep-init sdic)
  (with-current-buffer (sdicf-get-buffer sdic)
    (save-excursion
      (let ((inhibit-read-only t)) (erase-buffer))
      (let* ((coding (sdicf-get-coding-system sdic))
             (prog sdicf-grep-command)
             (file (sdicf-get-filename sdic))
             (is-rg (string-match "rg\\(\\.exe\\)?$" (file-name-nondirectory prog))))
        (let ((args (append
                     (if case '("-i") nil)
                     (if sdicf-grep-max-count (list (format "--max-count=%d" sdicf-grep-max-count)) nil)
                     (if is-rg
                         (if regexp '("-N") '("-N" "-F"))
                       (if regexp '("-E") '("-F")))
                     (list "-f" "-" file))))
          (with-temp-buffer
            (insert pattern)
            (apply #'sdicf-call-process-region
                   (point-min) (point-max) prog coding (sdicf-get-buffer sdic) nil args)))
        (sdicf-collect-entry-lines)))))



;;; Strategy `array'

(defun sdicf-array-available (sdic)
  (and (or (file-readable-p (sdicf-get-filename sdic))
           (signal 'sdicf-missing-file (list (sdicf-get-filename sdic))))
       (or (file-readable-p (concat (sdicf-get-filename sdic) ".ary"))
           (signal 'sdicf-missing-file (list (concat (sdicf-get-filename sdic) ".ary"))))
       (or (and (stringp sdicf-array-command)
                (executable-find sdicf-array-command))
           (signal 'sdicf-missing-executable '(sary)))))

(defalias 'sdicf-array-init 'sdicf-common-init)

(defalias 'sdicf-array-quit 'sdicf-common-quit)

(defun sdicf-array-search (sdic pattern &optional case regexp)
  "sary を使って検索を行う。

見つかったエントリのリストを返す。REGEXP が Non-nil の場合は設定エラーとする。"
  (sdicf-array-init sdic)
  (when regexp
    (signal 'sdicf-invalid-method '(regexp)))
  (with-current-buffer (sdicf-get-buffer sdic)
    (save-excursion
      (let ((inhibit-read-only t))
        (erase-buffer))
      (let* ((coding (sdicf-get-coding-system sdic))
             (file (sdicf-get-filename sdic))
             (args (append (if case '("-i") nil)
                           (list pattern file))))
        (if (and sdicf-array-max-count
                 (executable-find "head"))
            (let ((shell-command
                   (format "%s%s %s %s | head -n %d"
                           (shell-quote-argument sdicf-array-command)
                           (if case " -i" "")
                           (shell-quote-argument pattern)
                           (shell-quote-argument file)
                           sdicf-array-max-count)))
              (sdicf-call-process shell-file-name coding nil t nil
                                  shell-command-switch shell-command))
          (apply #'sdicf-call-process
                 sdicf-array-command coding nil t nil args)))
      (sdicf-collect-entry-lines))))


;;;------------------------------------------------------------
;;;             Interface functions
;;;------------------------------------------------------------

(defun sdicf-open (filename &optional coding-system strategy)
  "SDIC 形式の辞書をオープンする。

FILENAME は辞書のファイル名。STRATEGY は検索を行なう方式を指定する引数
で、次のいずれかの値を取る。

    `direct' - 辞書をバッファに読んで直接検索。
    `grep'   - rg または grep コマンドを用いて検索。
    `array'  - sary を用いた高速検索。

STRATEGY が省略された場合は sdicf-strategy-alist の値を使って自動的に
判定する。CODING-SYSTEM が省略された場合は、sdicf-default-coding-system
の値を使う。

SDIC 辞書オブジェクトは CAR が `SDIC' のベクタである。以下の4つの要素
を持つ。
    ・ファイル名
    ・辞書の coding-system
    ・strategy
    ・作業用バッファ"
  (let ((sdic (vector 'SDIC filename (or coding-system sdicf-default-coding-system) nil nil)))
    (aset sdic 3 (if strategy
                     (if (assq strategy sdicf-strategy-alist)
                         (if (funcall (nth 1 (assq strategy sdicf-strategy-alist)) sdic)
                             strategy)
                       (signal 'sdicf-invalid-strategy (list strategy)))
                   (or (car (cl-find-if
                             (lambda (e)
                               (condition-case nil
                                   (funcall (nth 1 e) sdic)
                                 (sdicf-errors nil)))
                             sdicf-strategy-alist))
                       (signal 'sdicf-decide-strategy nil))))
    sdic))

(defun sdicf-close (sdic)
  "SDIC形式の辞書をクローズする"
  (or (sdicf-object-p sdic)
      (signal 'wrong-type-argument (list 'sdicf-object-p sdic)))
  (funcall (nth 3 (assq (sdicf-get-strategy sdic) sdicf-strategy-alist)) sdic))

(defun sdicf-search (sdic method word)
  "SDIC 形式の辞書から WORD をキーとして検索を行う。

見付かったエントリのリストを返す。METHOD は検索法で、次のいずれかの値
を取る。

    `prefix' - 前方一致検索
    `suffix' - 後方一致検索
    `exact'  - 完全一致検索
    `text'   - 全文検索
    `regexp' - 正規表現検索

前方一致検索、後方一致検索、完全一致検索の場合は大文字/小文字を区別し
て検索を行う。全文検索および正規表現検索の場合は、case-fold-search の
値によって変化する。ただし、strategy によっては、指定された検索方式に
対応していない場合があるので、注意すること。対応していない場合の返り値
は、strategy による。"
  (or (sdicf-object-p sdic)
      (signal 'wrong-type-argument (list 'sdicf-object-p sdic)))
  (or (stringp word)
      (signal 'wrong-type-argument (list 'stringp word)))
  (funcall (nth 4 (assq (sdicf-get-strategy sdic) sdicf-strategy-alist))
           sdic
           (cond
            ((eq method 'prefix) (concat "<K>" (sdicf-encode-string (downcase word))))
            ((eq method 'suffix) (concat (sdicf-encode-string (downcase word)) "</K>"))
            ((eq method 'exact) (concat "<K>" (sdicf-encode-string (downcase word)) "</K>"))
            ((eq method 'text) word)
            ((eq method 'regexp) word)
            (t (signal 'sdicf-invalid-method (list method))))
           (sdicf-search-case-fold-p method)
           (eq method 'regexp)))

(defun sdicf-entry-headword (entry)
  "エントリ ENTRY の見出し語を返す。"
  (save-match-data
    (or (sdicf-entry-p entry)
        (signal 'wrong-type-argument (list 'sdicf-entry-p entry)))
    (sdicf-decode-string (substring entry (match-beginning 1) (match-end 1)))))

(defun sdicf-entry-keywords (entry &optional add-headword)
  "エントリ ENTRY の検索キーのリストを返す。
ADD-HEADWORD が Non-nil の場合は検索キーに見出し語を加えたリストを返す。"
  (or (sdicf-entry-p entry)
      (signal 'wrong-type-argument (list 'sdicf-entry-p entry)))
  (let ((start (match-end 0))
        (keywords (if (or add-headword (string= "<K>" (substring entry 0 3)))
                      (list (sdicf-decode-string (substring entry (match-beginning 1) (match-end 1)))))))
    (while (eq start (string-match "<.>\\([^<]+\\)</.>" entry start))
      (setq start (match-end 0)
            keywords (cons (sdicf-decode-string (substring entry (match-beginning 1) (match-end 1))) keywords)))
    (nreverse keywords)))

(defun sdicf-entry-text (entry)
  "エントリ ENTRY の本文を返す。"
  (or (stringp entry)
      (signal 'wrong-type-argument (list 'stringp entry)))
  (sdicf-decode-string (substring entry (string-match "[^>]*$" entry))))


(provide 'sdicf)

;;; sdicf.el ends here
