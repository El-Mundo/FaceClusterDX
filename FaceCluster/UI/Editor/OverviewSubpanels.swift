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
}
