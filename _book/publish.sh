#!/bin/bash
gitbook build .
git add .
git commit -m "update"
git push
git subtree push --prefix=_book origin gh-pages
