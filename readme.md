# FaceClusterDX
A face-clustering toolkit for MacOS (Silicon)



## Intro Panel

<img width="320" alt="Screenshot 2024-12-14 at 00 03 53" src="https://github.com/user-attachments/assets/f176d76b-8c64-40be-bd78-d6b200eb4873" />

The intro panel gives quick access to two options: [**load video**](#load-video) or [**load project**](#load-project).

### Load Project
A project is a file in **.fcproject** format generated by this application, which resumes the face-clustering networks created and edited by the user. A .fcproject file is manually generated by saving a project in the editor.

### Load Video
To start a new project, the user will have to select a video with the "load video" option. Directly supported formats are **.mp4** and **.mov**, but technically all formats compatible with the **AVFoundation** utility should be usable (tweaking might be necessary for esoteric formats, though).

<img width="320" alt="Screenshot 2024-12-14 at 00 12 14" src="https://github.com/user-attachments/assets/3e92147d-ee6f-4dc4-9e5c-c5ac2cc735bd" />

Successful decoding of a video file will direct the user to the import setting page. It gives the user two import settings: **frame extraction interval** ("analyze every") and **frame scaling**. **Frame extraction interval** is used to reduce the number of the frames used for face recognition, which improves stability for large video processing. It also supports two units for deciding the interval: second and frame. **Frame scaling** decides if the analyzed frames should be scaled down to provide further acceleration.



## Data Structure

This application stores all faces as objects with multiple **attributes**. Seven basic attributes are generated upon the face's being detected. These are frame index (integer), face box (4D vector), confidence (decimal), face rotation (3D vector generated by Apple's face API), Path (string, the relative path where the face is stored), cluster (string), and position (point variable).

All attributes align with one of the six types: integer, decimal, integer vector, decimal vector, string, and point. In addition to the basic attributes, the user can add new attributes to a network or remove the added attributes (basic attributes cannot be removed, but "position" can be replaced by other point attributes). The point type is a special type that is used for face clustering. In the editor's **Overview panel**, the user can decide an attribute of point type to be the **"display positioning attribute"**. This action will make the faces in the Network panel rearranged according to the new position attribute, and the distances between faces calculated based on the positioning attribute are used for dividing all faces into clusters.


## Editor

After loading a previous project or creating a new project with a video, the user will be navigated to the editor. The editor provides five panels for manipulating and interpreting the statistics generated by face recognition and clustering, including [**Network**](#network), [**Frames**](#Fframes), [**Overview**](#overview), [**Project**](#project), and [**Timeline**](#timeline).

### Network

<img width="480" alt="Screenshot 2024-12-14 at 00 54 04" src="https://github.com/user-attachments/assets/4ac20390-c8a2-4027-ab59-65d3fa8f5128" />

The Network panel is the default view of the editor. It provides a GUI-empowered interface for editing and fine-tuning the results of face clustering. In this page all faces are positioned based on the point attribute set as the **"display positioning attribute"**, while editing occurring in this panel is directly saved to that attribute's values.

The user can switch between two modes using **the Preview/Edit Button** in the toolbar. In the **Preview** mode, the button writes "Edit", and the user can drag the canvas to navigate the network preview. Mouse wheel is used to zoom in/out the canvas. **The Cluster button** shown in this mode allows the user to regenerate all clusters based on the current positions of all faces and a given distance. In the **Edit** mode, however, dragging will allow the user to move the positions of faces. The Cluster button is replaced with a slider that determines the range of dragging. if the slider is at the minimal value, only one face can be dragged at once, but if a higher range is picked, multiple faces within the cursor can be relocated together.

In both modes, the user can **deactivate** certain faces by right-clicking them. Deactivated faces are not included in data analysis and clustering but still stored within the network and can be recovered by another right-click in the Network panel.

There are also three modes for displaying the cluster results: **none**, **lines**, and **polygons**. The polygon mode is used by default, but it has an issue that when there are only two faces in a cluster, the cluster cannot be displayed. The lines mode addresses this issue by drawing lines between all pairs of faces in a cluster.

### Frames

<img width="480" alt="Screenshot 2024-12-14 at 00 55 05" src="https://github.com/user-attachments/assets/f23dd9de-3cba-4d29-9ace-e65eb1448b33" />

The Frames panel is used to control the results of facial recognition at frame-level accuracy.

The user can click a frame in the grid on the left to edit the faces in this frame. The buttons on top of the grid also allows the user to delete or import single frames as images.

In the panel on the right, the user could re-detect faces for the chosen frame. The user can also select a face in the frame by clicking the boxes on the image preview or the columns in the list below. They can delete the selected face or look at it in details by selecting a "aligning display" mode. This image shows the three modes of aligning display: **landmark lines** (left), **landmark points** (middle), and **aligned face** (right):

<img width="600" alt="Screenshot 2024-12-14 at 01 04 38" src="https://github.com/user-attachments/assets/69e2ee0e-4ad8-4a13-af7c-16df50cc8172" />

The difference between aligned face and the original picture is mild here because the shown image is frontal.

### Overview

<img width="480" alt="Screenshot 2024-12-14 at 17 49 15" src="https://github.com/user-attachments/assets/c060cd6d-698d-400b-bbf1-51f2cd7a04aa" />

The Overview panel offers an interface to quickly review all attributes of the loaded faces in current network. The user can assign any attributes of Point type as the network display positioning attribute here, but updating the positioning attribute will not automatically replace existing clusters.

The list display below shows all attributes of all faces in the loaded network (aka the **active network** of the project). Except for the first six attributes, all attributes are editable in this list. By double clicking an attribute, a text box will pop up below the list view and the user can input a new value for the attribute in the text box. If the input value is not properly formatted for the expected data type, however, the value will not be updated.

The Overview panel also provides several utilities in the right-top toolbar including:

(1) Export Full Face Images: to save all face images at full resolution (the original resolution cropped from the video file). This function requires that the loaded media file is stored at the original location and has been unchanged since the creation of current network.

(2) Export CSV: to save the network as a CSV file. Three types of CSV outputs are supported: empty template (a table with the attribute headers only), filled template (a table with attribute headers and sample inputs), and full table (a table with all attributes and their values).

<img width="320" alt="Screenshot 2024-12-14 at 18 02 20" src="https://github.com/user-attachments/assets/8b1ce1c0-8320-43b0-95b7-081ba092d593" />

(3) Conditional Selection: to allow the filtering of faces based on the values and integrity of an attribute.

(4) Disable Face (<img width="29" alt="Screenshot 2024-12-14 at 18 07 33" src="https://github.com/user-attachments/assets/9443fb7c-44af-4344-b3a5-28a6af34838b" />): to disable all selected faces.

<img width="320" alt="Screenshot 2024-12-14 at 18 02 47" src="https://github.com/user-attachments/assets/e03a67eb-60fd-4e66-b2c1-0b3bc8d23870" />

(5) Edit Selected: to assign values to an attribute for currently selected faces. This values can be a constant or a variable borrowed from other attributes.

(6) Delete Face (<img width="27" alt="Screenshot 2024-12-14 at 18 09 46" src="https://github.com/user-attachments/assets/565b1f87-1238-4a26-a64f-b77ae2d0d057" />): Remove all selected faces from network (irreversible).

(7) Create Attribute: (7.1) Facenet512: to generate a 512-D vector for all faces that are not deactivated (7.2) Custom CoreML: to load a CoreML model from device and use it to analyze the faces (7.3) T-SNE: to perform dimension reduction on a vector attribute that has more than 2 dimensions and generate a 2D Point attribute (or 1D decimal and 3D vector) for the faces based on the selected vector (can be slow; requires that a vector has been selected in the attribute header row) (7.4) Import CSV: to import values from a CSV file (7.5) Create Empty: to create an empty attribute for the current network and (optionally) assign a default value for this attribute.

(8) Remove Attribute: to remove the attribute selected in the attribute header row.

### Project

<img width="480" alt="Screenshot 2024-12-14 at 18 24 23" src="https://github.com/user-attachments/assets/964cf55a-8282-4d76-9538-2abac4a6c4c9" />

The project panel is typically used for multi-network projects. While all projects are one-network be default, this panel allows the user to import other networks into a project. Other networks are all saved under the path **Documents/Face Cluster Toolkit** by default as folders. The support for multiple networks is to enhance the timeline visualization component, which can be useful for reducing the demand of computational power for long videos. By dividing a long video into clips, importing them as separate networks, and combining them in the project, the user can perform face clustering for a long video while keeping each network at acceptable size.

<img width="480" alt="Screenshot 2024-12-14 at 18 24 29" src="https://github.com/user-attachments/assets/8462a821-c43a-42a5-886a-274cf3343dd2" />

After selecting a network, the user can also review all clusters in that network. Selecting a cluster displays all faces it contains. In the timeline, all clusters with the same name from different networks will be identified as pointing to the same character.

### Timeline

<img width="480" alt="Screenshot 2024-12-14 at 18 41 49" src="https://github.com/user-attachments/assets/0b8bdc78-d14e-42fe-b75d-dd53dc0fd7d8" />

<img width="480" alt="Screenshot 2024-12-14 at 18 41 52" src="https://github.com/user-attachments/assets/05122d59-b6f6-46ed-a11e-24dbeb7208c8" />

The timeline panel provides a quick visualization for the statistics. In the current version this component can be unstable, and exporting the data as CSV to be visualized with more established tools such as Plotly and SPSS is recommended.

The timeline panel is useful for researching certain patterns in relation to the video's structure. The X-Axis option is specifically designed to enhance the visualization of multi-network projects. The merge mode means that all faces from all networks in the project are placed at the exact x location indicating their appearance in the timeline of the original video file. The collapsed mode will collapse all networks based on their order stored in the project file. This order can be changed in the Project view. The Active mode means that only faces in the active network (the one being edited in the Network and Overview sections) will be places in the timeline, whilst other faces are places left to the timeline before media time 00:00.

## Misc

### References

| Referenced Projects | Content |
|---------------------|---------|
| [Facenet](https://github.com/davidsandberg/facenet/blob/master/LICENSE.md) | Facial attribute recognition model (Facenet512) |
| [MTCNN-Caffe](https://github.com/CongWeilin/mtcnn-caffe) | Face alignment models (MTCNN) |
| [Swift-TSNE](https://github.com/emannuelOC/swift-tsne) | T-SNE implemented for Swift (CPU) | 



### Know Issues

Manually adding jpg and jpeg files with the same file name will result in unexpected errors with face image identification. Using the import utility in the Frame view will avoid such issue by forcing all jpeg files to be imported as jpg format.

### To-dos

1. Improve T-SNE implement
2. Clean unused codes
3. Improve the stability of multi-network project editing
