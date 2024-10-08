;;; obtt.el --- Org babel tangle templates -*- lexical-binding: t; -*-

;; Copyright (c) 2018-2024 Abhinav Tushar

;; Author: Abhinav Tushar <lepisma@fastmail.com>
;; Version: 0.0.3
;; Package-Requires: ((emacs "25") (yasnippet "0.13.0") (helm "3.0"))
;; URL: https://github.com/lepisma/obtt

;;; Commentary:

;; Org babel tangle templates
;; This file is not a part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'org)
(require 'ob-tangle)
(require 'cl-lib)
(require 'ox)
(require 'yasnippet)
(require 'helm)


(defcustom obtt-templates-dir nil
  "Template directory"
  :type 'directory)

(defcustom obtt-seed-name ".obtt"
  "Name for the seed file"
  :type 'string)

(defun obtt-parse-args (args-string)
  (split-string (string-trim args-string)))

(defun obtt-all-files ()
  "Return all the output files involved in the template."
  (org-element-map (org-element-parse-buffer) 'src-block
    (lambda (blk)
      (let ((params (org-element-property :parameters blk)))
        (alist-get :tangle (org-babel-parse-header-arguments params))))))

(defun obtt-prepare-directories (files)
  (dolist (file files)
    (mkdir (file-name-directory (directory-file-name file)) t)))

(defun obtt-eval-blocks ()
  "Run all blocks marked with `:obtt eval'"
  (org-babel-map-src-blocks nil
    (let* ((obtt-args-string (alist-get :obtt (org-babel-parse-header-arguments header-args)))
           (obtt-args (if obtt-args-string (obtt-parse-args obtt-args-string))))
      (if (member "eval" obtt-args)
          (org-babel-execute-src-block nil nil '((:results . "none")))))))

(defun obtt-available-snippets ()
  "Look for all available obtt snippets"
  (if (file-exists-p obtt-templates-dir)
      (directory-files obtt-templates-dir nil "\\.obtt$")))

(defun obtt-expand-includes ()
  (org-export-expand-include-keyword nil (file-name-as-directory obtt-templates-dir)))

(defun obtt-read-template (template)
  (let* ((file (concat (file-name-as-directory obtt-templates-dir) template)))
    (with-temp-buffer
      (insert-file-contents-literally file)
      (org-mode)
      (obtt-expand-includes)
      (buffer-substring-no-properties (point-min) (point-max)))))

;;;###autoload
(defun obtt-tangle ()
  (interactive)
  (save-buffer)
  (org-mode)
  (let ((files (obtt-all-files)))
    (obtt-prepare-directories files)
    (org-babel-tangle)
    (obtt-eval-blocks)))

(defun obtt-insert-template (template)
  (yas-minor-mode)
  (let ((yas-indent-line nil))
    (yas-expand-snippet (obtt-read-template template))))

;;;###autoload
(defun obtt-new (directory &optional arg)
  "Generate a new seed file by asking for template. If prefix `arg'
is true, also tangle it automatically."
  (interactive "DStarting directory: \nP")
  (let ((seed-file (concat directory obtt-seed-name)))
    (if (file-exists-p seed-file)
        (message "Seed file already exists")
      (with-current-buffer (find-file (concat directory obtt-seed-name))
        (let ((template (helm :sources (helm-build-sync-source "templates" :candidates (obtt-available-snippets))
                              :buffer "*helm obtt*"
                              :prompt "Select template: ")))
          (obtt-insert-template template)
          (when arg
            (obtt-tangle)
            (kill-buffer)))))))

(provide 'obtt)

;;; obtt.el ends here
