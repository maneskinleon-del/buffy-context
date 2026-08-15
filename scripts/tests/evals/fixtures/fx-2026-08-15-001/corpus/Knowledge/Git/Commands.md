# Git — Referencia rápida

> Config del usuario: `git config user.name = "Manuel Gonzalez"`, `user.email = "mangonz970@gmail.com"`.
> Auth: `gh auth git-credential`.
> GitHub: `maneskinleon-del`.

## Flujo diario

```bash
git status                    # Ver estado
git add -p <archivo>          # Add interactivo (parcial)
git commit -m "mensaje"       # Commitar
git push origin <rama>        # Subir
git pull --rebase             # Traer cambios (rebase, no merge)
```

## Ramas

```bash
git branch                    # Listar ramas
git branch -a                 # Todas (incluye remotas)
git checkout -b <rama>        # Crear y cambiar
git branch -d <rama>          # Eliminar (segura)
git branch -D <rama>          # Eliminar (forzada)
git merge <rama>              # Merge (preferir --ff-only)
```

## Cambios

```bash
git log --oneline -10                  # Últimos 10 commits
git log --oneline --graph --all        # Árbol visual
git diff                               # Cambios sin stage
git diff --staged                      # Cambios staged
git show <commit>                      # Ver commit específico
git blame <archivo>                    # Quién cambió qué
```

## Deshacer

```bash
git restore <archivo>                  # Descartar cambios sin stage
git restore --staged <archivo>         # Unstage
git reset --soft HEAD~1                # Deshacer último commit (sin perder cambios)
git reset --hard HEAD~1                # Deshacer último commit (perder cambios)
git revert <commit>                    # Revertir commit (seguro, crea nuevo commit)
```

## Stash

```bash
git stash                              # Guardar cambios temporales
git stash pop                          # Recuperar y eliminar stash
git stash list                         # Ver stashes
git stash drop                         # Eliminar stash
```

## gh CLI

```bash
gh auth status                         # Verificar auth
gh repo create <nombre> --public       # Crear repo
gh repo clone <user>/<repo>            # Clonar
gh pr create                           # Crear PR
gh pr list                             # Listar PRs
gh issue list                          # Listar issues
```

## Config

```bash
git config --global user.name "Manuel Gonzalez"
git config --global user.email "mangonz970@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.autocrlf input
```
