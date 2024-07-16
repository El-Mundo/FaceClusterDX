//
//  Overview.swift
//  FaceCluster
//
//  Created by El-Mundo on 28/06/2024.
//

import SwiftUI

struct Overview: View {
    @State var network: FaceNetwork
    var context: Editor
    @State var tableWidth: CGFloat = 0
    @State var selectedAttribute: String?
    //@State var selectedFaces: [TableFace] = []
    
    public static var forceSelectFaces: [UUID] = []
    @State private var pushForcedSelection: Bool = false
    @State var forceResetTable: Bool = false
    @State var alertMessage: String = ""
    @State var alertTitle: String = ""
    @State var alertedAction: (()->Void)?
    @State var alertCancelAction: (()->Void)?
    @State var waitingMessage: String = "Eating Spaghetti with chopsticks..."
    
    @State var addEmptyAttribute: Bool = false
    @State var showProgress = false
    @State var progressValue: CGFloat = 0.0
    @State var showCircleProgress: Bool = false
    @State var showAlert: Bool = false
    @State var alertType: OverviewAlertType = .general
    @State var showMessageSheet: Bool = false
    @State var showGroupEditor: Bool = false
    @State var showCondition: Bool = false
    @State var showSelectableAlert: Bool = false
    /// This variables forces the variables referenced by a Sheet to be updated one frame previous to the Sheet initialisation.
    /// It's added to solve SwiftUI's issue where variables in Sheet cannot be updated timely.
    ///
    /// Values: 0- None, 1- Circle progress, 2- Sheet message, 3- Progress bar, 4- Request facenet, 5- Local ML, 6- TSNE.
    @State var messageSheetFlag: Int = 0
    @State var requestTSNE: Bool = false
    @State var requestLocalML: Bool = false
    @State var showCSVImporter: Bool = false
    @State var requestFacenet: Bool = false
    
    @State var forceTableDisableSelection: Bool = false
    @State var forceTableDeletingSelection: Bool = false
    
    enum OverviewAlertType {
        case selectable
        case destructive
        case general
    }
    
    @State var tempTextField: String = ""
    @State var tempTextField1: String = ""
    @State var tempIntegerField: Int?
    @State var tempBoolField: Bool = false
    @State var cachedUrls: [URL]?
    
    let lightGrey = Color(red: 0.87, green: 0.87, blue: 0.87)
    
    var body : some View {
        HStack {
            NetworkOverview(network: network, context: self, layoutKey: network.layoutKey)
            VStack {
                Button("Export Full Face Images") {
                    requestSavingHDImages()
                }.padding(.bottom, 6)
                    .controlSize(.large)
                
                Menu() {
                    Button("Empty Template") {
                        exportCSVEmpty()
                    }
                    
                    Button("Filled Template") {
                        exportCSVExample()
                    }
                    
                    Button("Full Table") {
                        exportCSVFull()
                    }
                } label: {
                    Label("Export CSV", systemImage: "tablecells.badge.ellipsis")
                }.controlSize(.large).frame(width: 160)
                
                
                
                Text("Faces:").frame(height: 16).padding(.top, 12)
                VStack {
                    HStack {
                        Button("Conditional Select") {
                            showCondition.toggle()
                        }
                        
                        Button() {
                            forceTableDisableSelection.toggle()
                        } label: {
                            Image(systemName: "wrongwaysign")
                        }
                    }
                    
                    HStack {
                        Button() {
                            showGroupEditor.toggle()
                        } label: {
                            Label("Edit Selected", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: { forceTableDeletingSelection.toggle() }, label: { Image(systemName: "trash.slash.fill")}).buttonStyle(.borderedProminent).tint(.red)
                    }
                }.controlSize(.large)
                
                
                
                Text("Attributes:").frame(height: 16).padding(.top, 12)
                HStack {
                    Menu() {
                        Button("Facenet512") {
                            requestFacenet512()
                        }
                        
                        Button("Custom CoreML") {
                            initLocalCoreML()
                        }
                        
                        Button("T-SNE") {
                            requestTsne()
                        }
                        
                        Button("Import CSV") {
                            showCSVImporter.toggle()
                        }
                
                        
                        Button("Create Empty") {
                            clearTempInput()
                            addEmptyAttribute = true
                        }
                        
                    } label: {
                        Label("Create", systemImage: "plus.circle")
                    }
                    .menuButtonStyle(BorderlessPullDownMenuButtonStyle())
                    .menuStyle(.borderedButton)
                    .frame(width: 112)
                    .controlSize(.large)
                    
                    Button(action: {
                        if(selectedAttribute != nil) {
                            showDestructiveMessageAlert(String(localized: "Do you really wish to remove the field \(selectedAttribute!) from the network? This action is irreversible and will delete all references to the field in face files."), action: deleteAttribute)
                        }
                    }) {
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .frame(width: 96)
                    .controlSize(.large)
                }
            }
            .frame(minWidth: 256, maxWidth:  256, minHeight: 256, maxHeight: .infinity)
            .background(lightGrey)
            .onChange(of: messageSheetFlag) {
                if(messageSheetFlag == 1) {
                    showCircleProgress = true
                } else if(messageSheetFlag == 2) {
                    showMessageSheet = true
                } else if(messageSheetFlag == 3) {
                    showProgress = true
                } else if(messageSheetFlag == 4) {
                    requestFacenet = true
                } else if(messageSheetFlag == 5) {
                    requestLocalML = true
                } else if(messageSheetFlag == 6) {
                    requestTSNE = true
                }
            }
            .sheet(isPresented: $addEmptyAttribute) {
                CreateEmptyAttributePanel(context: self).frame(width: 360, height: 240)
            }
            .sheet(isPresented: $requestLocalML) {
                RequestCustomCoreML(context: self).frame(minWidth: 500, maxWidth: 720, minHeight: 240, maxHeight: 960)
            }
            .sheet(isPresented: $requestTSNE) {
                RequestTSNEPanel(context: self, attribute: selectedAttribute!).frame(width: 480, height: 320)
            }
            .sheet(isPresented: $requestFacenet) {
                RequestFacenetPanel(context: self).frame(width: 360, height: 240)
            }
            .sheet(isPresented: $showCircleProgress) {
                VStack {
                    Text(waitingMessage)
                        .font(.headline)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))
                }.frame(width: 350, height: 240)
            }
            .sheet(isPresented: $showMessageSheet) {
                ScrollView {
                    VStack {
                        Text(tempTextField1)
                            .font(.headline)
                            .padding(.bottom, 12)
                        Text(tempTextField).frame(minWidth: 320, maxWidth: 640).padding(.horizontal, 12)
                        Button("OK") {
                            messageSheetFlag = 0
                            tempTextField = ""
                            tempTextField1 = ""
                            showMessageSheet = false
                        }.controlSize(.large).padding(.top, 12)
                    }.frame(minWidth: 350, maxWidth: 960, minHeight: 240, maxHeight: 960)
                }
            }
            .sheet(isPresented: $showProgress) {
                VStack {
                    Text(waitingMessage)
                        .font(.headline)
                    ProgressView(value: progressValue)
                        .padding(.horizontal, 32)
                }.frame(width: 350, height: 240)
            }
            .alert(isPresented: $showAlert) {
                if(alertType == .destructive) {
                    Alert(title: Text(alertTitle), message: Text(alertMessage), primaryButton: .destructive(Text("Proceed"), action: alertedAction), secondaryButton: .cancel())
                } else if (alertType == .selectable) {
                    if(alertCancelAction == nil) {
                        Alert(title: Text(alertTitle), message: Text(alertMessage), primaryButton: .default(Text("Proceed"), action: alertedAction), secondaryButton: .cancel())
                    } else {
                        Alert(title: Text(alertTitle), message: Text(alertMessage), primaryButton: .default(Text(tempTextField), action: alertedAction), secondaryButton: .default(Text(tempTextField1), action: alertCancelAction))
                    }
                } else {
                    Alert(title: Text(alertTitle), message: Text(alertMessage))
                }
            }.fileImporter(isPresented: $showCSVImporter, allowedContentTypes: [.commaSeparatedText], onCompletion: {
                result in
                importFieldsFromCSVFile(url: result)
            })
        }
            
        FaceNetworkTable(network: network, context: self)
            .overlay {
                GeometryReader { geo in
                    let rect = geo.frame(in: .global)
                    Color.clear.onAppear() {
                        tableWidth = rect.width
                    }.onChange(of: rect.width) {
                        tableWidth = rect.width
                    }
                }
            }
            .onChange(of: pushForcedSelection, {
                
            })
    }
    
    func clearTempInput() {
        tempTextField = ""
        tempTextField1 = ""
        messageSheetFlag = 0
        tempIntegerField = nil
        tempBoolField = false
    }
    
    func initLocalCoreML() {
        clearTempInput()
        messageSheetFlag = 5
    }
    
    func requestTsne() {
        if(selectedAttribute == nil) {
            showSecondaryMessage(String(localized: "Please select a Vector attribute in the table header to perform T-SNE on."))
            return
        }
        let type = network.attributes.first(where: {$0.name == selectedAttribute})
        if(type != nil) {
            if(type?.type != .Vector) {
                showSecondaryMessage(String(localized: "The selected attribute is not of Vector type."))
                return
            }
        }
        clearTempInput()
        messageSheetFlag = 6
    }
    
    func requestFacenet512() {
        clearTempInput()
        tempTextField = "Facenet512"
        tempTextField1 = "Facenet512_Conf"
        messageSheetFlag = 4
    }
    
    func facenetCompleted() {
        forceResetTable = !forceResetTable
        hideProgressBar()
        clearTempInput()
    }
    
    func facenet() {
        showProgressBar(message: String(localized: "Performing Facenet512 prediction..."))
        DispatchQueue.global(qos: .userInitiated).async {
            let time = Date.now
            let facenet = FacenetWrapper()
            /*let images = network.getAlignedImageArray()
             facenet.detectFacesAsync(in: images)*/
            facenet.detectFacesSync(in: network, batchSize: 512, progress: $progressValue)
            //let vectorKey = network.getUniqueKeyName(name: "Facenet512")
            //let confidenceKey = network.getUniqueKeyName(name: "Facenet512_Conf")
            let vectorKey = tempTextField
            let confidenceKey = tempTextField1
            network.forceAppendAttribute(key: vectorKey, type: .Vector, dimensions: 512)
            network.forceAppendAttribute(key: confidenceKey, type: .Decimal, dimensions: nil)
            facenet.writeResults(key1: vectorKey, key2: confidenceKey)
            print("Time lapse: \(Date.now.timeIntervalSince(time))")
            facenetCompleted()
        }
    }
    
    func tsne(att: String, dim: Int) {
        let tuple = network.attributeVectorsToDoubleArray(name: att)
        guard let array = tuple.0 else {
            showGeneralMessageOnlyAlert(tuple.3)
            return
        }
        let name = network.getUniqueKeyName(name: "\(att)_\(dim)D")
        let type = dim < 3 ? (dim < 2 ? AttributeType.Decimal : AttributeType.Point) : AttributeType.Vector
        let corrupted = tuple.2
        let refIndices = tuple.1
        let d = network.getVectorDimension(name: att)
        
        showWaitingCircle()
        
        Task
        {
            let tsne = T_SNE(data: array, dimensions: d, perplexity: 30)
            let tr = tsne.transform(targetDimensions: dim, learningRate: 10, maxIterations: 1000)
            
            if(type == .Point) {
                network.forceAppendAttribute(key: name, type: .Point, dimensions: 1)
            } else if(type == . Decimal) {
                network.forceAppendAttribute(key: name, type: .Decimal, dimensions: 1)
            } else {
                network.forceAppendAttribute(key: name, type: .Vector, dimensions: dim)
            }
            
            //let tr = SwiftTsne().transform(data: array)
            for i in 0..<tr.count {
                let face = network.faces[refIndices[i]]
                if(type == .Point) {
                    let np = FacePoint((DoublePoint(x: tr[i][0], y: tr[i][1])), for: name)
                    face.forceUpdateAttribute(for: FacePoint.self, key: name, value: np)
                } else if(type == . Decimal) {
                    let nd = FaceDecimal(tr[i][0], for: name)
                    face.forceUpdateAttribute(for: FaceDecimal.self, key: name, value: nd)
                } else {
                    let nv = FaceVector(tr[i], for: name)
                    face.forceUpdateAttribute(for: FaceVector.self, key: name, value: nv)
                }
                face.updateSaveFileAtOriginalLocation()
            }
            
            hideWaitingCircle()
            
            let cor = corrupted > 0 ? " \(corrupted) faces with corrupted data format found and skipped." : ""
            showSecondaryMessage(String(localized: "Successfully saved T-SNE \(dim)D reduction for \(att) as attribute \(name).") + cor, title: String(localized: "Success"))
            forceResetTable.toggle()
        }
    }
    
    func showWaitingCircle(message: String=String(localized: "Updating network...")) {
        waitingMessage = message
        messageSheetFlag = 1
    }
    
    func hideWaitingCircle() {
        showCircleProgress = false
        messageSheetFlag = 0
    }
    
    func showGeneralMessageOnlyAlert(_ message: String=String(localized: "Failed to update face network."), title: String=String(localized: "Warning")) {
        alertMessage = message
        alertTitle = title
        alertType = .general
        showAlert = true
    }
    
    func showDestructiveMessageAlert(_ message: String="Proceed to perform a destructive action", title: String=String(localized: "Warning"), action: @escaping ()->Void) {
        alertMessage = message
        alertTitle = title
        alertedAction = action
        alertType = .destructive
        showAlert = true
    }
    
    func showSecondaryMessage(_ msg: String, title: String=String(localized: "Message")) {
        tempTextField = msg
        tempTextField1 = title
        messageSheetFlag = 2
    }
    
    
    @State var cachedCSVConsole: CSVConverter.CSVLog?
    func showSelectableMessageAlert(_ message: String="Selection reqruied", title: String=String(localized: "Warning"), action: @escaping ()->Void, proceedButton: String=String(localized: "OK"), cancelAction: (()->Void)?=nil, cancelButoon: String=String(localized: "Cancel")) {
        alertMessage = message
        alertTitle = title
        alertedAction = action
        alertCancelAction = cancelAction
        alertType = .selectable
        tempTextField = proceedButton
        tempTextField1 = cancelButoon
        showAlert = true
    }
    
    func showProgressBar(message: String=String(localized: "Updating network...")) {
        waitingMessage = message
        messageSheetFlag = 3
    }
    
    func hideProgressBar() {
        showProgress = false
        messageSheetFlag = 0
        progressValue = 0
    }

}
