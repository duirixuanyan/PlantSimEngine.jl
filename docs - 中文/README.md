**Summary:**  
Add Chinese translation for documentation and source code comments

**Description:**  
This PR introduces Chinese-language support for the project's documentation and source code. The changes include:

**Added Folders:**  
1. `docs - 中文` – Contains the fully translated documentation in Chinese  
2. `src - 中文` – Contains the source code files with Chinese translations of code comments

**Key Features:**  
- Complete Chinese translation of the documentation for better accessibility to Chinese-speaking users  
- Translated source code comments to help Chinese developers understand and contribute to the codebase  
- No modifications to the original source logic or functionality – only translation of text content

**Notes:**  
- The original `docs` and `src` folders remain unchanged  
- The translation covers all user-facing documentation and in-code documentation (docstrings/comments)  
- Ready for review by bilingual contributors to ensure translation accuracy

This effort aims to make the project more inclusive and accessible to the Chinese developer community.

---

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