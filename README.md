# Dotfiles for MacOS
### Sub-Directory Naming

-	*`lowercase`* - for packages to `stow` install in `$HOME` (the default)

-	leading `_` - for non-`stow`-able packages, e.g.

-	*`TitleCase`* - for packages which need `root` permissions, e.g. top-level of filesysyem at `/` 

-	leading `@` - for environment packages and subpackages, e.g. 

Having a convention for sub-package naming enables a `.stow-global-ignore` file such that sub-packages are not symlinked when stowing parent package.