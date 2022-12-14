;;; emoji.el --- generate EMOJI SKK-JISYO from CLDR annotations ja.xml -*- coding: utf-8 -*-

;;; Commentary:

;;  Unicode Common Locale Data Repository
;;    https://unicode.org/Public/cldr/36.1/cldr-common-36.1.zip
;;    common/annotations/*.xml

;;; License:
;;    https://www.unicode.org/license.html

;;; NOTE:
;; (1) yuÃ¨bÇng /ð¥®/
;;     è¦åºãèªã« ASCII ç¯å²å¤ã® latin ãããã°ãASCII ç¯å²åã¸ç½®ãæãã¦ãã¾ãã

;; (2) ãå¯¿å¸ /ð£/
;;     æ¼¢å­æ··ããã®è¦åºãèªã¨ãªããªãããï¼ããªå¥åã§ããªããè£å®ãã§ããªãï¼
;;     åºåãã¦ãã¾ããã validate2()
;;     ãããããã¹ã¦æ¼¢å­ã§æ§æãããè¦åºãèªã§ããã°ã
;;     L è¾æ¸ unannotated ã¨çªåãã¦æ¼¢å­ãããªã¸å¤æãã¦ãã¾ãã

;; (3) åè£ã«ã¯ skk ã¢ããã¼ã·ã§ã³ã¨ãã¦ U+9999 ãä»å ãã¦ãã¾ãã

;;; Code:

(require 'dom)

(defun xml-to-jisyo (file &optional kanjionly)
  (let* ((xml-dom-tree (with-temp-buffer (insert-file-contents file)
                                         (libxml-parse-xml-region (point-min) (point-max))))
         (doms-anno (dom-by-tag xml-dom-tree 'annotation)))
    (mapc #'(lambda (dom-anno)
              (let ((annos (split-string (dom-text dom-anno) " | "))
                    (cp (dom-attr dom-anno 'cp)))
                (mapc #'(lambda (anno)
                          (and (validate anno)
                               (if kanjionly
                                   (validate3 anno)
                                 (validate2 anno))
                               (princ (format "%s /%s;%s/\n" (treat anno) cp (get-codepoint cp)))))
                      annos)))
          doms-anno)))

(defun get-codepoint (str)
  (mapconcat #'(lambda (s)
               (format "U+%x" (string-to-char s)))
           (split-string str "" t) ","))

(defun validate (anno)
  ;; ã²ã¨ã¤ã§ã t ãªã nilããã¹ã¦ nil ãªã t
  ;; ç¡è¦ããè¦åºãèªãåè¨ãã ... validate() ã¯ nil ãè¿ã
  (not (or (string-match "\\s-" anno)   ; ã¹ãã¼ã¹ãå«ã
           (string-match "/" anno)      ; åç¬ `/'
           (string-match (char-to-string 215) anno) ; "Ã"
           (string-match (char-to-string 247) anno) ; "Ã·"
           )))

(defun validate2 (anno)
  ;; æ¼¢å­ç­ãå«ãæå­åã¯ãè¦åºãèªã¨ãã¦ã¯ä¸é©å½ ... nil ãè¿ã
  (let* ((strings (split-string anno "" t))
         (lst (mapcar #'(lambda (c)
                          (aref char-script-table (string-to-char c)))
                     strings)))
    (not (or (member 'han lst)
             (member 'cjk-misc lst)
             (member 'symbol lst)
             ))))

(defun validate3 (anno)
  ;; ãã¹ã¦ãæ¼¢å­ã ãã§æ§æããã¦ããæå­åã§ããã° t
  ;; ï¼æå­ã§ãæ¼¢å­ä»¥å¤ãããã° nil
  (let* ((strings (split-string anno "" t))
         (result t))
    (dolist (s strings)
      (unless (eq 'han (aref char-script-table (string-to-char s)))
        (setq result nil)))
    result))

(defun treat (str)
  (let ((lst `((,(char-to-string 232) . "e") ; Ã¨
               (,(char-to-string 234) . "e") ; Ãª
               (,(char-to-string 241) . "n") ; Ã±
               (,(char-to-string 243) . "o") ; Ã³
               (,(char-to-string 257) . "o") ; Ä
               (,(char-to-string 333) . "o") ; Å
               (,(char-to-string 464) . "i") ; Ç
               (,(char-to-string 8220) . "")
               (,(char-to-string 8221) . ""))))
    (mapc #'(lambda (pair)
              (setq str (replace-regexp-in-string (car pair) (cdr pair) str)))
          lst))
  (when (string-match (format "[%s-%s]" (char-to-string 126) (char-to-string 12288))
                      str)
    (princ (format "Found non-ascii : %s\n" str) 'external-debugging-output))

  (setq str (downcase str))

  ;; çä»®åãå¹³ä»®åã¸å¤æ
  (let ((diff (- #x30a1 #x3041))
        (lst (split-string str "" t))
        c)
    (mapconcat #'(lambda (s)
                   (setq c (string-to-char s))
		   (if (and (<= #x30a1 c) (<= c #x30f6))
		       (char-to-string (- c diff))
		     (char-to-string c)))
               lst "")))

(defun ja ()
  (xml-to-jisyo "ja.xml"))

(defun kanjionly ()
  (xml-to-jisyo "ja.xml" t))

(defun en ()
  (xml-to-jisyo "en.xml"))

(defvar kanji2kana-alist nil)

(defun make-alist ()
    (let (alist)
      (with-temp-buffer
        (insert-file-contents "SKK-JISYO.L.unannotated")
        (goto-char (point-min))
        (re-search-forward "^ã /.+$")
        (beginning-of-line)
        (while (not (eobp))
          (let* ((line (buffer-substring (point) (progn (end-of-line) (point))))
                 (lst (split-string line " /"))
                 (kana-midasi (car lst))
                 (kanji-cands (format "/%s" (car (cdr lst)))))
            (unless (string-match ">" kana-midasi)
              (setq alist (cons (cons kana-midasi kanji-cands) alist))))
          (forward-line)))
      alist))

(defun kanji-to-kana ()
  (setq kanji2kana-alist (make-alist))
  (with-temp-buffer
      (insert-file-contents "SKK-JISYO.emoji.kanji")
      (let ((c (count-lines (point-min) (point-max)))
            (i 1))
        (goto-char (point-min))
        (while (re-search-forward "^\\([^ ]+\\) /\\(.+\\)/$" nil t)
          (let ((kanji (match-string 1))
                (cands (match-string 2))
                kana-lst)
            (when (zerop (mod i 20))
              (princ (format "kanji-to-kana : %d/%d, %s\n" i c kanji) 'external-debugging-output))
            (when (setq kana-lst (get-kana kanji))
              (mapc #'(lambda (kana)
                        (princ (format "%s /%s/\n" kana cands)))
                    kana-lst)))
            (setq i (1+ i))))))

(defun get-kana (kanji-key)
  (let ((kanji-key (format "/%s/" kanji-key))
        result)
    (dolist (cell kanji2kana-alist)
      (when (string-match kanji-key (cdr cell))
        (setq result (cons (car cell) result))))
    result))

(provide 'emoji)

;;; emoji.el ends here
