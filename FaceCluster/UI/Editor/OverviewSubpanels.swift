//
//  OverviewSubpanels.swift
//  FaceCluster
//
//  Created by El-Mundo on 09/07/2024.
//

import SwiftUI

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
                    let semaphore = DispatchSemaphore(value: 0)
                    context.showWaitingCircle(message: String(localized: "Updating references in face files"))
                    DispatchQueue.global(qos: .userInitiated).async {
                        for face in network.faces {
                            face.forceUpdateAttribute(for: getFaceAttributeType(type: type), key: name, value: con!)
                            face.updateSaveFileAtOriginalLocation()
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                    context.hideWaitingCircle()
                }
                
                context.forceResetTable = !context.forceResetTable
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
        //showGeneralMessageOnlyAlert(String(localized: "Successfully saved \(saved) images at \(path)."), title: String(localized: "Successful"))
    }
    
    func exportCSVFull() {
        showWaitingCircle(message: String(localized: "Saving CSV..."))
        let t = network.savedPath.appending(path: "Table Full (\(AppDelegate.getDateString())).csv")
        let (saved, info) = CSVConverter().converteNetworkFull(network, save: t)
        hideWaitingCircle()
        if(saved) {
            showGeneralMessageOnlyAlert(String(localized: "Saved table at ") + t.path(percentEncoded: false), title: String(localized: "Success"))
        } else {
            showGeneralMessageOnlyAlert(String(localized: "Failed to save updated table, message: ") + info)
        }
    }
    
    func exportCSVEmpty() {
        showWaitingCircle(message: String(localized: "Saving CSV..."))
        let t = network.savedPath.appending(path: "Table Empty (\(AppDelegate.getDateString())).csv")
        let (saved, info) = CSVConverter().generateEmptyTemplateForNetwork(network, save: t)
        hideWaitingCircle()
        if(saved) {
            showGeneralMessageOnlyAlert(String(localized: "Saved table at ") + t.path(percentEncoded: false), title: String(localized: "Success"))
        } else {
            showGeneralMessageOnlyAlert(String(localized: "Failed to save updated table, message: ") + info)
        }
    }
    
    func exportCSVExample() {
        showWaitingCircle(message: String(localized: "Saving CSV..."))
        let t = network.savedPath.appending(path: "Table Filled (\(AppDelegate.getDateString())).csv")
        let (saved, info) = CSVConverter().generateSampleTemplateForNetwork(network, save: t)
        hideWaitingCircle()
        if(saved) {
            showGeneralMessageOnlyAlert(String(localized: "Saved table at ") + t.path(percentEncoded: false), title: String(localized: "Success"))
        } else {
            showGeneralMessageOnlyAlert(String(localized: "Failed to save updated table, message: ") + info)
        }
    }
    
    func importFieldsFromCSVFile(url: Result<URL, Error>) {
        switch url {
        case .success:
            showWaitingCircle(message: String(localized: "Decoding URL file..."))
            guard let u = try? url.get() else { break }
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
    
}