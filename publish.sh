#!/bin/bash
git add .
git commit -m "update"
git push
gitbook build .
git subtree push --prefix=_book origin gh-pages
