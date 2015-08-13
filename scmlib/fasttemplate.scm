(define (load-wara-fasttemplate)
  (define (apply-chain ori-target . proc-ls)
    (let loop ((target ori-target)
               (proc-ls proc-ls))
      (if (null? proc-ls)
        target
        (loop ((car proc-ls) target)
              (cdr proc-ls)))))

  (define (match-string re str)
    (rxmatch-substring (rxmatch re str)))

  (define (cur-line)
    (editor-get-row-string (editor-get-cur-row)))

  (define (basename path)
    (regexp-replace-all #/.*\\([^.]*)(\..*)?$/ path "$1"))

  (define (read-all filename)
    (call-with-input-file
      filename
      (lambda (in)
        (let loop ((char-ls '())
                   (char (read-char in)))
          (if (eof-object? char)
            (list->string (reverse char-ls))
            (loop (cons char char-ls) (read-char in)))))))

  (define (template-path name)
    (string-append (app-get-tool-dir) "template\\" name ".txt"))

  (define (read-template)
    (let* ((name (app-input-box "template name"))
           (path (template-path name)))
      (if (not (file-exists? path))
        (exit)
        (read-all path))))

  (define (expand-var template)
    (let ((var-table (make-hash-table 'string=?)))
      (regexp-replace-all
        #/\{\{_(?:var|input)_:(\w+)\}\}/
        template
        (lambda (m)
          (let ((tag (rxmatch-substring m 1)))
            (if (not (hash-table-exists? var-table tag))
              (let ((var (app-input-box tag)))
                (if (not (string? var))
                  (exit)
                  (hash-table-put! var-table tag var))))
            (hash-table-get var-table tag ""))))))

  (define (expand-name template)
    (regexp-replace-all
      #/\{\{_name_\}\}/
      template
      (lambda (m)
        (basename (editor-get-filename)))))

  (define (expand-expr template)
    (regexp-replace-all
      #/\{\{_expr_:(.+)\}\}/
      template
      (lambda (m)
        (eval (read (open-input-string (rxmatch-substring m 1)))))))

  (define (append-indent template)
    (let ((indent (match-string #/^\s*/ (cur-line))))
      (regexp-replace-all
        #/(?!\A)^/
        template
        indent)))

  (define (move-to-end-of-line)
    (editor-set-row-col
      (editor-get-cur-row)
      (string-length (cur-line))))

  (define (move-to-_cursor_)
    (editor-search-string "\\{\\{_cursor_\\}\\}")
    (editor-delete-selected-string))

  (define (fasttemplate-expand)
    (let ((template (read-template)))
      (move-to-end-of-line)
      (editor-paste-string
        (apply-chain
          template
          expand-var
          expand-name
          expand-expr
          append-indent))
      (move-to-_cursor_)))

  (define fasttemplate-key
    (if (symbol-bound? 'fasttemplate-key)
      fasttemplate-key
       "Ctrl+d"))

  (app-set-key fasttemplate-key fasttemplate-expand))

(load-wara-fasttemplate)
