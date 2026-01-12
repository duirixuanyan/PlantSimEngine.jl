# Step 1: Prepare Files
In your `PlantSimEngine.jl` directory:

- Rename the original `src` folder to `src_en` (as a backup).  
- Rename your translated `src - 中文` folder to `src` (disguise it as the original version).

# Step 2: Modify `make.jl` to Point to the Local Version  
Edit `docs - 中文/make.jl` to instruct Julia not to search for the package in the C: drive, but to use the modified package in the G: drive directly.

# Step 3: Generate Documentation  
Run `julia --project=@. make.jl`.

At this point, Documenter will read from `G:\GitHub\PlantSimEngine.jl\src` (which is the Chinese-translated version you just renamed), and the generated documentation will naturally contain the Chinese source code comments.

# Step 4: Restore (Optional)  
After generating the documentation, if you wish to restore the original state:

- Rename `src` back to `src - 中文`.  
- Rename `src_en` back to `src`.

**I don't have a better solution at the moment, sorry.**