;;; pshell-mode.el --- Mode for editing Powershell scripts

;; Copyright (C) 2009 Frédéric Perrin

;; Author: Frédéric Perrin <frederic (dot) perrin (arobas) resel (dot) fr>
;; Keywords: Powershell, Monad, MSH

;; This file is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published
;; by the Free Software Foundation, either version 3 of the License,
;; or (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Comment:
;; This is still WIP.
;;
;; This was written from scratch, without using Vivek Sharma's code:
;; it had issues I wanted to correct, but unfortunately there were no
;; licence indication, and Vivek didn't answered my mails.
;;
;; This is still pretty basic: there is indentation, syntax
;; hilighting, speedbar/imenu support. The indentation is pretty naïve
;; but robust, and sufficient for my current needs.

(setq debug-on-error t)

(defvar pshell-indent 8
  "Amount of horizontal space to indent after, for instance, an
opening brace")

(defvar pshell-continuation-indent 4
  "Amount of horizontal space to indent a continuation line")

(defvar pshell-continued-regexp  ".*\\(|[\\t ]*\\|`\\)$"
  "Regexp matching a continued line (ending either with an
explicit backtick, or with a pipe).")

(defun pshell-continuation-line-p ()
  "Returns t is the current line is a continuation line (i.e. the
previous line is a continued line, ending with a backtick or a pipe"
  (interactive)
  (save-excursion
    (forward-line -1)
    (looking-at pshell-continued-regexp)))

(defun pshell-indent-line-amount ()
  "Returns the column to which the current line ought to be indented."
  (interactive)
  (beginning-of-line)
  (let ((closing-paren (looking-at "[\t ]*[])}]")))
    ;; a very simple indentation method: if on a continuation line (i.e. the
    ;; previous line ends with a trailing backtick or pipe), we indent relative
    ;; to the continued line; otherwise, we indent relative to the ([{ that
    ;; opened the current block.
    (if (pshell-continuation-line-p)
	(progn
	  (while (pshell-continuation-line-p)
	    (forward-line -1))
	  (+ (current-indentation) pshell-continuation-indent))
      (condition-case nil
	  (progn
	    (backward-up-list)
	    ;; indentation relative to the opening paren: if there is text (no
	    ;; comment) after the opening paren, vertically align the block
	    ;; with this text; if we were looking at the closing paren, reset
	    ;; the indentation; otherwise, indent the block by pshell-indent.
	    (cond ((not (looking-at ".[\t ]*\\(#.*\\)?$"))
		   (forward-char)
		   (skip-chars-forward " \t")
		   (current-column))
		  (closing-paren
		   (current-indentation))
		  (t
		   (+ (current-indentation) pshell-indent))))
	(scan-error ;; most likely, we are at the top-level
	 0)))))

(defun pshell-indent-line ()
  "Indent the current line of powershell mode, leaving the point
in place if it is inside the meat of the line"
  (interactive)
  (let ((savep (> (current-column) (current-indentation)))
	(amount (save-excursion (pshell-indent-line-amount))))
    (if savep
	(save-excursion (indent-line-to amount))
      (indent-line-to amount))))


;; Taken from <http://www.manning.com/payette/AppCexcerpt.pdf> which seems the
;; closest to a grammar definition for powershell. It is not complete, and
;; contains some inaccuracies (e.g. it says that variables match \$[:alnum:]+,
;; so $_ is not a variable it seems...)

(defvar pshell-keywords
  (regexp-opt '("begin" "break" "catch" "continue" "data" "do" "dynamicparam"
		"else" "elseif" "end" "exit" "filter" "finally" "for" "foreach"
		"from" "function" "if" "in" "param" "process" "return"
		"switch" "throw" "trap" "try" "until" "while"))
  "Powershell keywords")

(defvar pshell-operators
  (regexp-opt '("and" "as" "band" "bnot" "bor" "bxor" "casesensitive"
		"ccontains" "ceq" "cge" "cgt" "cle" "clike" "clt" "cmatch"
		"cne" "cnotcontains" "cnotlike" "cnotmatch" "contains"
		"creplace" "eq" "exact" "f" "file" "ge" "gt" "icontains"
		"ieq" "ige" "igt" "ile" "ilike" "ilt" "imatch" "ine"
		"inotcontains" "inotlike" "inotmatch" "ireplace" "is"
		"isnot" "le" "like" "lt" "match" "ne" "not" "notcontains"
		"notlike" "notmatch" "or" "replace" "wildcard"))
  "Powershell operators")

(defvar pshell-scope-names
  (regexp-opt
  '("env" "function" "global" "local" "private" "script" "variable"))
  "Names of scopes in Powershell mode.")

;; Taken from Get-Variable on a fresh shell, merged with man
;; about_automatic_variables
(defvar pshell-builtin-variables
  (regexp-opt
   '("^" "_" "$" "?" "Args" "ConfirmPreference" "ConsoleFileName"
     "DebugPreference" "Error" "ErrorActionPreference" "ErrorView"
     "ExecutionContext" "foreach" "FormatEnumerationLimit" "HOME" "Host"
     "Input" "LASTEXITCODE" "MaximumAliasCount" "MaximumDriveCount"
     "MaximumErrorCount" "MaximumFunctionCount" "MaximumHistoryCount"
     "MaximumVariableCount" "MyInvocation" "NestedPromptLevel" "OFS"
     "OutputEncoding" "PID" "PROFILE" "PSHOME" "PWD" "ProgressPreference"
     "ReportErrorShowExceptionClass" "ReportErrorShowInnerException"
     "ReportErrorShowSource" "ReportErrorShowStackTrace" "ShellId"
     "ShouldProcessPreference" "ShouldProcessReturnPreference" "StackTrace"
     "VerbosePreference" "WarningPreference" "WhatIfPreference" "false"
     "input" "lastWord" "line" "null" "true" ))
  "Names of the built-in Powershell variables.")

(defvar pshell-font-lock-keywords-1
  `(;; Type annotations
    ("\\[\\([[:word:].]+\\(\\[\\]\\)?\\)\\]" 1 font-lock-type-face)
    ;; syntaxic keywords
    (,(concat "\\<" pshell-keywords "\\>") . font-lock-keyword-face)
    ;; operators
    (,(concat "\\<-" pshell-operators "\\>") . font-lock-builtin-face)
    ;; the REQUIRES mark
    ("^#\\(REQUIRES\\)" 1 font-lock-warning-face t))
  "Keywords for the first level of font-locking in Powershell mode.")

(defvar pshell-font-lock-keywords-2
  (append
   pshell-font-lock-keywords-1
   `(;; Built-in variables
     (,(concat "\\$\\(" pshell-builtin-variables "\\)\\>")
      1 font-lock-builtin-face t)))
  "Keywords for the second level of font-locking in Powershell mode.")

(defvar pshell-font-lock-keywords-3
  (append
   pshell-font-lock-keywords-2
   `(;; Variables in curly brackets
     ("\\${\\([^}]+\\)}" 1 font-lock-variable-name-face)
     ;; Variables, with a scope
     (,(concat "\\$\\(" pshell-scope-names "\\):"
	       "\\([[:alnum:]_]+\\)")
      (1 (cons font-lock-type-face '(underline)))
      (2 font-lock-variable-name-face))
     ;; Variables, without a scope. XXX: unify this with the
     ;; previous rule?
     ("\\$\\([[:alnum:]_]+\\)" 1 font-lock-variable-name-face)
     ;; hilight properties, but not the methods (personnal preference)
     ("\\.\\([[:alnum:]_.]+\\)\\>\\s *[^(]" 1 font-lock-variable-name-face)))
  "Keywords for the maximum level of font-locking in Powershell mode.")


(defvar pshell-mode-syntax-table (make-syntax-table)
  "Syntax table for Powershell mode")

(modify-syntax-entry ?# "<" pshell-mode-syntax-table)
(modify-syntax-entry ?\n ">" pshell-mode-syntax-table)
;; Powershell uses a backtick as its escape character.
(modify-syntax-entry ?` "\\" pshell-mode-syntax-table)
(modify-syntax-entry ?\\ "_" pshell-mode-syntax-table)
(modify-syntax-entry ?- "w" pshell-mode-syntax-table)
(modify-syntax-entry ?' "\"" pshell-mode-syntax-table)


(defvar pshell-imenu-expression
  `(("Functions" "function \\(\\w+\\)" 1)
    ("Top variables" ,(concat "^\\$\\(" pshell-scope-names "\\)?:?"
			      "\\([[:alnum:]_]+\\)")
     2))
  "List of regexps matching important expressions, for speebar & imenu.")

(if (require 'speedbar)
    (speedbar-add-supported-extension ".ps1?"))

(defvar pshell-compile-command
  '(format "powershell.exe -NoLogo -Noninteractive & '%s'" (buffer-file-name))
  "Default command used to invoke a powershell script")


;; the hook is automatically run by derived-mode
(defvar pshell-mode-hook '(imenu-add-menubar-index)
  "Hook run after the initialization of Powershell mode.")

(define-derived-mode pshell-mode fundamental-mode "PS"
  "A major mode for editing Powershell script files."
  (set (make-local-variable 'indent-line-function) 'pshell-indent-line)
  (set (make-local-variable 'font-lock-defaults)
       '((pshell-font-lock-keywords-1
	  pshell-font-lock-keywords-2
	  pshell-font-lock-keywords-3)
	 nil t))
  (set (make-local-variable 'comment-start) "# ")
  (set (make-local-variable 'comment-start-skip) "#+\\s*")
  ;; not sure why this is not the default
  (set (make-local-variable 'parse-sexp-ignore-comments) t)
  (set-syntax-table pshell-mode-syntax-table)
  (set (make-local-variable 'imenu-generic-expression)
       pshell-imenu-expression)
  (set (make-local-variable 'imenu-case-fold-search) nil)
  (set (make-local-variable 'compile-command) pshell-compile-command))

(provide 'pshell-mode)
