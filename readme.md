# asmirnov.xyz

1. Edit `.md` files in `./content/` folder
2. Build them into `.html` to `./out/` folder

   Install dependencies:

   ```bash
   sudo pacman -S pandoc plantuml graphviz
   ```

   ```bash
   ./build.sh
   ```

3. Serve `./out/` folder with any web server
