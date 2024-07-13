//
//  OverviewSubpanels.swift
//  FaceCluster
//
//  Created by El-Mundo on 09/07/2024.
//

import SwiftUI
import UniformTypeIdentifiers

extension Overview {
    struct CreateEmptyAttributePanel: View {
        @State var context: Overview
        @State var tempAttributeType: AttributeType = .Decimal
        @State var content: String = ""
        
        var body : some View {
            Text("Create an Empty Face Attribute").font(.headline)
            
            VStack {
                TextField("Attribute Name", text: $context.tempTextField)
                Picker(selection: $tempAttributeType, label: Text("Type")) {
                    ForEach(AttributeType.allCases, id: \.self) {
                        Text(getFaceAttributeTypeName(type: $0))
                    }
                }
                .pickerStyle(.menu)
                
                TextField("Attribute Dimensions (Vector only)", value: $context.tempIntegerField, format: IntegerFormatStyle()).padding(.vertical, 12)
                
                TextField("Default (Optional)", text: $content)
            }.frame(width: 300)
            
            HStack {
                Button("Cancel", role: .cancel) { context.addEmptyAttribute = false }.tint(.white)
                Button("Create", action: createEmpty).tint(.blue)
            }.controlSize(.large).padding(.top, 24).buttonStyle(.borderedProminent)
        }
        
        func createEmpty() {
            context.addEmptyAttribute = false
            let name = context.tempTextField
            let dim = context.tempIntegerField ?? 0
            let type = tempAttributeType
            let network = context.network
            let errTitle = String(localized: "Attribute Creation Error")
            
            if(name.trimmingCharacters(in: [" "]) == "") {
                context.showGeneralMessageOnlyAlert(String(localized: "Cannot create an attribute with an empty name"), title: errTitle)
            } else if(network.attributes.contains(where: { return $0.name == name })) {
                context.showGeneralMessageOnlyAlert(String(localized: "Specified attribute name has been used"), title: errTitle)
            } else if((type == .Vector || type == .IntVector) && dim < 1) {
                context.showGeneralMessageOnlyAlert(String(localized: "Cannot create a vector with negative or zero dimensions"), title: errTitle)
            } else {
                var con: (any FaceAttribute)? = nil
                if(content != "") {
                    let c = decodeStringAsAttribute(as: type, content, for: name)
                    if(c.0) {
                        con = c.1
                    } else {
                        context.showGeneralMessageOnlyAlert(String(localized: "Cannot decode String \"\(content)\" as ") + getFaceAttributeTypeName(type: type), title: errTitle)
                        return
                    }
                }
                
                network.forceAppendAttribute(key: name, type: type, dimensions: dim)
                
                if(con != nil) {
                    //let semaphore = DispatchSemaphore(value: 0)
                    context.showWaitingCircle(message: String(localized: "Updating references in face files"))
                    DispatchQueue.global(qos: .userInitiated).async {
                        for face in network.faces {
                            face.forceUpdateAttribute(for: getFaceAttributeType(type: type), key: name, value: con!)
                            face.updateSaveFileAtOriginalLocation()
                        }
                        //semaphore.signal()
                        context.hideWaitingCircle()
                        context.forceResetTable = !context.forceResetTable
                    }
                    //semaphore.wait()
                } else {
                    context.forceResetTable = !context.forceResetTable
                }
            }
        }
    }
    
    
    
    func requestSavingHDImages() {
        let path = network.savedPath.appending(path: "HD Faces")
        if(!AppDelegate.checkIfDirectoryExists(url: path)) {
            do {
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
                confirmSavingHDImages()
            } catch {
                showGeneralMessageOnlyAlert(error.localizedDescription)
                return
            }
        } else {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
                let jpgFiles = contents.filter { $0.pathExtension.lowercased() == "jpg" }
                let jpgCount = jpgFiles.count
                if(jpgCount > 0) {
                    cachedUrls = jpgFiles
                    let p = path.path(percentEncoded: false)
                    showDestructiveMessageAlert(String(localized: "This action will replace the \(jpgCount) jpg files in \(p). Confirm to proceed?"), title: String(localized: "Replacing Existing Files"), action: confirmSavingHDImages)
                } else {
                    confirmSavingHDImages()
                }
            } catch {
                showGeneralMessageOnlyAlert(error.localizedDescription)
                return
            }
        }
    }
    
    func confirmSavingHDImages() {
        showWaitingCircle(message: String(localized: "Saving full size face images..."))
        
        Task {
            if(cachedUrls != nil) {
                let f = FileManager.default
                for url in cachedUrls! {
                    do {
                        try f.removeItem(at: url)
                        print(url.absoluteString + " removed")
                    } catch {
                        print(error)
                        continue
                    }
                }
                cachedUrls = nil
            }
            
            var saved = 0
            for face in network.faces {
                guard let img = face.getFullSizeImage() else {
                    continue
                }
                let name = face.path!.lastPathComponent
                let s = ImageUtils.saveImageAsJPG(img, at: network.savedPath.appending(path: "HD Faces/\(name).jpg"))
                if(s) {
                    saved += 1
                }
            }
            
            hideWaitingCircle()
            let path = network.savedPath.appending(path: "HD Faces/").path(percentEncoded: false)
            showSecondaryMessage(String(localized: "Successfully saved \(saved) images at \(path)."), title: String(localized: "Successful"))
        }
        //showGeneralMessageOnlyAlert(String(localized: "Successfully saved \(saved) images at \(path)."), title: String(localized: "Successful"))
    }
    
    func exportCSVFull() {
        showWaitingCircle(message: String(localized: "Saving CSV..."))
        Task {
            let t = network.savedPath.appending(path: "Table Full (\(AppDelegate.getDateString())).csv")
            let (saved, info) = CSVConverter().converteNetworkFull(network, save: t)
            hideWaitingCircle()
            if(saved) {
                showGeneralMessageOnlyAlert(String(localized: "Saved table at ") + t.path(percentEncoded: false), title: String(localized: "Success"))
            } else {
                showGeneralMessageOnlyAlert(String(localized: "Failed to save updated table, message: ") + info)
            }
        }
    }
    
    func exportCSVEmpty() {
        showWaitingCircle(message: String(localized: "Saving CSV..."))
        Task {
            let t = network.savedPath.appending(path: "Table Empty (\(AppDelegate.getDateString())).csv")
            let (saved, info) = CSVConverter().generateEmptyTemplateForNetwork(network, save: t)
            hideWaitingCircle()
            if(saved) {
                showGeneralMessageOnlyAlert(String(localized: "Saved table at ") + t.path(percentEncoded: false), title: String(localized: "Success"))
            } else {
                showGeneralMessageOnlyAlert(String(localized: "Failed to save updated table, message: ") + info)
            }
        }
    }
    
    func exportCSVExample() {
        showWaitingCircle(message: String(localized: "Saving CSV..."))
        Task {
            let t = network.savedPath.appending(path: "Table Filled (\(AppDelegate.getDateString())).csv")
            let (saved, info) = CSVConverter().generateSampleTemplateForNetwork(network, save: t)
            hideWaitingCircle()
            if(saved) {
                showGeneralMessageOnlyAlert(String(localized: "Saved table at ") + t.path(percentEncoded: false), title: String(localized: "Success"))
            } else {
                showGeneralMessageOnlyAlert(String(localized: "Failed to save updated table, message: ") + info)
            }
        }
    }
    
    func importFieldsFromCSVFile(url: Result<URL, Error>) {
        switch url {
        case .success:
            guard let u = try? url.get() else { break }
            showWaitingCircle(message: String(localized: "Decoding URL file..."))
            Task {
                let c = CSVConverter()
                let result = c.importCSV(network, url: u)
                hideWaitingCircle()
                if(result.0) {
                    cachedCSVConsole = c.importLog
                    showSelectableMessageAlert(result.1, title: String(localized: "Success"), action: logCSVImportConsole, proceedButton: String(localized: "Details..."), cancelAction: clearCSVImportConsole, cancelButoon: String(localized: "OK"))
                    c.importLog = nil
                    forceResetTable.toggle()
                } else {
                    showGeneralMessageOnlyAlert(result.1)
                }
            }
            break
        case .failure:
            break
        }
    }
    
    func clearCSVImportConsole() {
        self.cachedCSVConsole = nil
        self.tempTextField = ""
        self.tempTextField1 = ""
        self.showAlert = false
    }
    
    func logCSVImportConsole() {
        var string = String(localized: "Skipping following attributes due to its type being preserved: \n")
        guard let console = cachedCSVConsole else {
            return
        }
        for p in console.preservedFields {
            string.append(p + ", ")
        }
        if(string.hasSuffix(", ")) {
            string.removeLast()
            string.removeLast()
        }
        string.append("\n\n" + String(localized: "Skipping following lines due to missing identifier attribute (\(FA_PreservedFields[6])): \n"))
        for p in console.skippedLines {
            string.append("\(p), ")
        }
        if(string.hasSuffix(", ")) {
            string.removeLast()
            string.removeLast()
        }
        string.append("\n\n" + String(localized: "Skipping following cells due to corrupted data format: \n"))
        for p in console.skippedCells {
            string.append("\(p), ")
        }
        if(string.hasSuffix(", ")) {
            string.removeLast()
            string.removeLast()
        }
        
        self.showAlert = false
        showSecondaryMessage(string, title: "Details")
        self.cachedCSVConsole = nil
    }
    
    func checkNameUsability(name: String) -> (Bool, String) {
        if(name.trimmingCharacters(in: [" "]) == "") {
            return (false, String(localized: "Cannot create an attribute with an empty name"))
        } else if(network.attributes.contains(where: { return $0.name == name })) {
            return (false, String(localized: "Specified attribute name has been used"))
        } else {
            return (true, "")
        }
    }
    
    
    struct RequestFacenetPanel: View {
        @State var context: Overview
        
        var body : some View {
            Text("Facenet512").font(.headline)
            
            VStack {
                HStack {
                    Text("Atrribute Name:")
                    TextField("Name for result attribute", text: $context.tempTextField)
                }
                
                HStack {
                    Text("Confidence:")
                    TextField("Name for confidence attribute", text: $context.tempTextField1).padding(.vertical, 12)
                }
            }.frame(width: 300)
            
            HStack {
                Button("Cancel", role: .cancel) { context.requestFacenet = false; context.clearTempInput(); }.tint(.white)
                Button("Analyse", action: checkAttributeName).tint(.blue)
            }.controlSize(.large).padding(.top, 24).buttonStyle(.borderedProminent)
        }
        
        func checkAttributeName() {
            context.requestFacenet = false
            let name1 = context.tempTextField, name2 = context.tempTextField1
            if(name1.trimmingCharacters(in: [" "]) == "" || name2.trimmingCharacters(in: [" "]) == "") {
                context.showGeneralMessageOnlyAlert(String(localized: "Cannot create an attribute with an empty name"))
            } else if(context.network.attributes.contains(where: { return $0.name == name1 || $0.name == name2 })) {
                context.showDestructiveMessageAlert(String(localized: "There are one or more attribute names conflicting with existing attributes in the network. Confirming this action will result in these attributes to be replaced. Continue?"), action: context.facenet)
            } else {
                context.facenet()
            }
        }
    }
    
    func deleteAttribute() {
        guard let attribute = selectedAttribute else {
            return
        }
        if(FA_PreservedFields.contains(where: { $0 == attribute })) {
            showAlert = false
            showSecondaryMessage(String(localized: "Cannot remove a preserved field from the network."), title: String(localized:  "Warning"))
            return
        } else if(network.layoutKey == attribute) {
            showAlert = false
            showSecondaryMessage(String(localized: "Cannot delete the field used for display position in the network view."), title: String(localized:  "Warning"))
            return
        }
        
        showWaitingCircle(message: String(localized: "Deleting attribute and its references in faces"))
        Task {
            network.attributes.removeAll(where: { $0.name == attribute })
            for face in network.faces {
                if(face.attributes.keys.contains(attribute)) {
                    face.attributes.removeValue(forKey: attribute)
                    face.updateSaveFileAtOriginalLocation()
                }
            }
            forceResetTable.toggle()
            hideWaitingCircle()
        }
    }
    
    struct RequestCustomCoreML: View {
        @State var context: Overview
        @State var name: String = ""
        @State var info: String = "Waiting for model..."
        @State var showFI = false
        @State var warn: String = ""
        @State var showWarn: Bool = false
        @State var url: URL?
        @State var mlWrapper: LocalCoreML?
        @State var faceWidth: Int?
        @State var align: Bool = true
        @State var faceHeight: Int?
        let exts = [UTType(filenameExtension: "mlmodel")!, UTType(filenameExtension: "mlpackage", conformingTo: .directory)!]
        
        var body : some View {
            Text("Load a Local CoreML Model").font(.headline).padding(.top, 12)
            
            VStack {
                HStack {
                    Text("Model:")
                    Text(url == nil ? "..." : url!.path(percentEncoded: false))
                    Button("Browse") {
                        showFI = true
                    }
                }
                .padding(.top, 12)
                
                Text(info).padding(.bottom, 12)
                
                HStack {
                    Text("Save attributes as:")
                    TextField("Name root for saved attributes", text: $name)
                }.padding(.top, 12)
                if(!name.trimmingCharacters(in: [" "]).isEmpty) {
                    Text("The result multidimensional arrays will be stored as " + "\(name)_(output column 1), \(name)_(output column 1)_Conf, \(name)_(output column 2)...").padding(.bottom, 12)
                } else {
                    Text("Attribute name cannot be empty").padding(.bottom, 12)
                }
                
                HStack {
                    Text("Batch size:")
                    TextField("Default 1", value: $context.tempIntegerField, format: IntegerFormatStyle())
                }
                
                Toggle("Align Faces", isOn: $align).padding(.vertical, 12)
                
                Text("Resize face to:")
                HStack {
                    Text("Width")
                    TextField("In pixel, optional", value: $faceWidth, format: IntegerFormatStyle())
                        .padding(.trailing, 12)
                    Text("Height")
                    TextField("In pixel, optional", value: $faceHeight, format: IntegerFormatStyle())
                        .padding(.trailing, 12)
                }
            }
            .padding(.horizontal, 12)
            .fileImporter(isPresented: $showFI, allowedContentTypes: exts, onCompletion: importModel)
            .frame(minWidth: 500, maxWidth: 720, minHeight: 240, maxHeight: 960)
            
            HStack {
                Button("Cancel", role: .cancel) { context.requestLocalML = false; context.clearTempInput(); }.tint(.white)
                Button("Analyse", action: process).tint(.blue)
            }.alert(isPresented: $showWarn) {
                Alert(title: Text("Warning"), message: Text(warn), dismissButton: .cancel())
            }.controlSize(.large).padding([.top, .bottom], 24).buttonStyle(.borderedProminent)
        }
        
        func showNonFatalErrorInsideSheet(message: String) {
            warn = message
            showWarn = true
        }
        
        func process() {
            if(name.trimmingCharacters(in: [" "]).isEmpty) {
                showNonFatalErrorInsideSheet(message: String(localized: "Cannot create an attribute with an empty name"))
                return
            }
            context.requestFacenet = false
            guard let ml = mlWrapper else {
                showNonFatalErrorInsideSheet(message: String(localized: "Please load a local CoreML file first"))
                return
            }
            if(!ml.compilable) {
                showNonFatalErrorInsideSheet(message: String(localized: "There is an error when compiling the CoreML model: \(info)"))
                return
            }
            if(ml.vnModel==nil) {
                context.requestLocalML = false
                context.clearTempInput()
                context.showGeneralMessageOnlyAlert(String(localized: "An error occurred when fitting the CoreML model for Vision framework."))
                return
            }
            
            if(faceWidth != nil && faceHeight != nil) { ml.faceBoxSize = CGSize(width: faceWidth!, height: faceHeight!) }
            let mln = mlWrapper?.url.deletingPathExtension().lastPathComponent ?? "local CoreML model"
            context.requestLocalML = false
            context.showProgressBar(message: String(localized: "Processing faces with \(mln)..."))
            Task {
                ml.batchPredict(in: context.network.faces, size: context.tempIntegerField ?? 1, align: align, progressBar: $context.progressValue)
                context.showProgressBar(message: String(localized: "Writing results..."))
                let msg = ml.writeResults(progressBar: context.$progressValue, root: name, net: context.network)
                context.clearTempInput()
                context.hideProgressBar()
                context.forceResetTable = !context.forceResetTable
                context.showSecondaryMessage(msg, title: "Success")
            }
        }
        
        func importModel(r: Result<URL, Error>) {
            switch r {
            case .success:
                mlWrapper = LocalCoreML(url: try! r.get(), faceSize: nil, indicator: $info)
                url = try? r.get()
                break
            case .failure:
                break
            }
        }
    }
    
    struct RequestTSNEPanel: View {
        @State var context: Overview
        @State var t = 2
        let attribute: String
        
        var body : some View {
            Text("Facenet512").font(.headline)
            
            VStack {
                Text("Perform T-SNE dimension reduction for \"\(attribute)\"")
                
                HStack {
                    Picker("Target dimension:", selection: $t) {
                        Text("1D").tag(1)
                        Text("2D").tag(2)
                        Text("3D").tag(3)
                    }
                    .pickerStyle(.inline)
                }.padding(.horizontal, 24)
            }
            
            HStack {
                Button("Cancel", role: .cancel) { context.requestTSNE = false; context.clearTempInput(); }.tint(.white)
                Button("Analyse", action: analyse).tint(.blue)
            }.controlSize(.large).padding(.top, 24).buttonStyle(.borderedProminent)
        }
        
        func analyse() {
            context.requestTSNE = false
            context.tsne(att: attribute, dim: t)
        }
    }
    
}
