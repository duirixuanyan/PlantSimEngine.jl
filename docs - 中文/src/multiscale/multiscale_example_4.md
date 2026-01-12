# 使用 PlantGeom 可视化植物

我们已经创建了我们的玩具植物，其中一个有趣的部分就是实际将其可视化！

让我们来看看如何用 [PlantGeom](https://github.com/VEZY/PlantGeom.jl) 辅助包实现这一点。

我们将重复使用植物教程第 3 部分生成的 mtg：[修复植物模拟中的Bug](@ref)。因此，你需要先运行那部分的模拟，或者将相应的脚本文件包含进当前的代码（这里我们选择包含脚本文件）：

```julia
using PlantSimEngine
using MultiScaleTreeGraph
using PlantSimEngine.Examples
using Pkg
Pkg.add("CSV")
using CSV
include("ToyPlantSimulation3.jl")
```

你需要在环境中添加 PlantGeom 以及一个兼容的可视化包。这里我们使用 Plots：

```julia
using Plots
using PlantGeom
```

仅需这些步骤，就能比在控制台打印 MTG 有更好的显示效果。你只需输入下方一行代码即可：

```julia
RecipesBase.plot(mtg)
```

效果如下图所示：
![MTG Plots visualization](../www/mtg_plot_1.svg)

就这样！

我们可以看到根朝一个方向扩展，而节间和它们的叶片则朝另一个方向生长。

当然，这样已经挺好了，但我们还可以更进一步。

PlantGeom 能够根据 MTG 中的信息渲染几何体。如果树图中的某个节点有一个带有网格和变换的 `:geometry` 属性，它就能利用这些信息来构建植物结构。这个网格可以是每个节点独有的，也可以是基于一个参考网格，对每个节点进行复制和变换得到。

!!! note 
    本页面只是用于演示 PlantGeom 的功能，并没有追求非常真实或美观的可视化效果。一些随机性可以让植物看起来更有生机，但这样做也会让代码更难理解和维护，因此这里没有采用。

我们的 MTG 目前还没有这样的属性，所以我们需要遍历每个节点，给它们分配网格并计算合适的变换方式。对于相关的三个尺度：节间、根和叶片，我们将分别用一个参考网格。

我们会用到 Meshes 包中的一些基础几何体和变换函数，还需要用到 TransformsBase 和 Rotations 包中的一些辅助函数。对于叶片，我们将用 PlyIO 包读取一个 .ply 文件，这里面存有一个非常简化的叶片+叶柄网格。

另外，我们还将让植物呈现对生十字排列（opposite decussate）：每对叶片成对出现，且每对之间沿茎轴旋转 90 度。

用于给节点添加几何体属性的函数如下：
```julia 
PlantGeom.Geometry(; ref_mesh<:RefMesh, transformation=Identity(), dUp=1.0, dDwn=1.0, mesh::Union{SimpleMesh,Nothing}=nothing)
```

对于本例，我们只需要关心前两个参数。对于每一个单一的节间和根节点，可以直接使用简单的圆柱作为网格。

```julia
using PlantGeom.Meshes

# 节间和根将使用圆柱体作为网格

cylinder() = Meshes.CylinderSurface(1.0) |> Meshes.discretize |> Meshes.simplexify

refmesh_internode = PlantGeom.RefMesh("Internode", cylinder())
refmesh_root = PlantGeom.RefMesh("Root", cylinder())
```

一个用于从 .ply 文件读取叶片顶点和面信息的简单函数：

```julia
Pkg.add("PlyIO")
using PlyIO
function read_ply(fname)
    ply = PlyIO.load_ply(fname)
    x = ply["vertex"]["x"]
    y = ply["vertex"]["y"]
    z = ply["vertex"]["z"]  
    points = Meshes.Point.(x, y, z)
    connec = [Meshes.connect(Tuple(c .+ 1)) for c in ply["face"]["vertex_indices"]]
    Meshes.SimpleMesh(points, connec)
end

leaf_ply = read_ply("examples/leaf_with_petiole.ply")
refmesh_leaf = PlantGeom.RefMesh("Leaf", leaf_ply)
```

```julia
Pkg.add("TransformsBase")
Pkg.add("Rotations")
import TransformsBase: →
import Rotations: RotY, RotZ, RotX
```

!!! note 
    我们将使用 X、Y、Z 作为标准的笛卡尔坐标轴，其中 Z 轴朝上。

接下来可以编写一个函数，为我们的 MTG 添加几何信息。

该函数从基部节点开始遍历 MTG，并为每个遇到的节点添加变换信息。

下面的代码仅针对节间（为便于理解）：

```julia
# 给MTG添加几何信息，并进行变换
function add_geometry!(mtg, refmesh_internode) 
    
    # 节间的累加偏移高度
    internode_height = 0.0

    # 基础网格的相对缩放比例（基准圆柱半径为1）
    internode_width = 0.5

    # 基础网格的长度
    internode_length = 1.0

    traverse!(mtg) do node
        if symbol(node) == "Internode"
            # 先缩放，再根据累计高度进行平移
            mesh_transformation = Meshes.Scale(internode_width, internode_width, internode_length) → Meshes.Translate(0.0, 0.0, internode_height)
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_internode, transformation=mesh_transformation)
            
            internode_height += node_length
        end
    end
end
```

我们只需要为茎干选择一个宽度，并在遍历时逐步递增高度，将下一个节间放置到正确的位置。

注意 Meshes.jl 提供的默认圆柱体朝上，因此无需旋转。根的处理也类似，只需向下平移，并且需要从原点下方开始。

我们可以使用 GLMakie 渲染后端可视化这个简单的茎结构：

```julia
add_geometry!(mtg, refmesh_internode)

# 可视化网格
using GLMakie
viz(mtg)
```    

![玩具植物——仅有茎](../www/toy_plant_stem_only.png)

另一方面，叶片的网格需要进行旋转，但它本身已经沿 X 轴对齐，因此不需要像圆柱一样做初始的重新定向。叶柄起点在原点，所以除了把它们平移到叶片的高度之外，还需要根据节间半径在 Z 轴方向之外进行平移。由于叶子网格本身长度只有 0.1 单位，而我们的节间宽度有 0.5，因此还需要进行缩放。

我们还可以将叶片稍微上抬，使其略微朝上。

如果你使用了其他网格，请注意它们的初始平移、朝向和缩放，通常需要多次试验和调整比例及变换参数才能得到理想效果。

下面给出用于为玩具植物所有器官添加几何体的完整代码：

```julia
# 为MTG添加各器官的几何信息及变换
function add_geometry!(mtg, refmesh_internode, refmesh_root, refmesh_leaf) 
    
    # 节间的累加高度，根的累加深度
    internode_height = 0.0
    root_depth = 0.0

    # 基础网格的相对缩放比例（基础圆柱高度为1，半径为1）
    internode_width = 0.5
    root_width = 0.2

    # 基础网格的长度
    internode_length = 1.0
    root_length = 1.0

    # 用于调整叶片网格到场景比例的经验系数
    leaf_mesh_scale = 25

    leaf_scale_width = 0.4 * leaf_mesh_scale
    leaf_scale_height = 0.4 * leaf_mesh_scale
    
    # 用于实现叶片对生轮换的辅助参数
    leaf_rotation = MathConstants.pi / 2.0
    i = 0

    traverse!(mtg) do node
        if symbol(node) == "Internode"
            # 先缩放，再按累计高度平移
            mesh_transformation = Meshes.Scale(internode_width, internode_width, internode_length) → Meshes.Translate(0.0, 0.0, internode_height)
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_internode, transformation=mesh_transformation)
            
            internode_height += internode_length

            # 叶片相对于母节间，在节间长度的一半处放置
            for chnode in children(node)               
                if symbol(chnode) == "Leaf" 
                    mesh_transformation = Meshes.Scale(leaf_scale_width, leaf_scale_width, leaf_scale_height) → Meshes.Rotate(RotX(-MathConstants.pi / 6.0)) → Meshes.Translate(0.0, -internode_width, internode_height - internode_length / 2.0) → Meshes.Rotate(RotZ(leaf_rotation))
                    chnode.geometry = PlantGeom.Geometry(ref_mesh=refmesh_leaf, transformation=mesh_transformation)
                    # 为实现叶片对生，第二片叶子比第一片多旋转180°
                    leaf_rotation += MathConstants.pi
                end                
            end

            # 对生轮换，每对之间轮换90°
            i += 1
            if i % 2 == 0
                leaf_rotation = MathConstants.pi / 2.0
            else
                leaf_rotation = MathConstants.pi
            end

        elseif symbol(node) == "Root"
            mesh_transformation = Meshes.Scale(root_width, root_width, root_length) → Meshes.Translate(0.0, 0.0, root_depth) → Meshes.Rotate(RotZ(MathConstants.pi))
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_root, transformation=mesh_transformation)
            root_depth -= root_length
        end
    end
end
```

现在，让我们来可视化这株完全生长、具备全部特性的植物吧：

```julia
# 可视化网格
using GLMakie
viz(mtg)    
```

你将会得到如下的图像场景：

![带根和叶片的玩具植物](../www/toy_plant.png)

欢迎尝试让这棵植物变得更漂亮、更有色彩，或更具物理真实感——你可以在 PlantSimEngine 侧使用更真实的模型，或者在 Plantgeom 端设计更精细的几何结构。