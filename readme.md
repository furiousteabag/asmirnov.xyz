# asmirnov.xyz

1. Edit `.md` files in `./content`
2. Build them into `.html` to `./out/` folder

```bash
./build.sh
```

Build dependencies:

```bash
sudo pacman -S pandoc plantuml graphviz
```

3. Serve `./out/` folder with any web server
