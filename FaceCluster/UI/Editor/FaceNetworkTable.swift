//
//  NetworkOverview.swift
//  FaceCluster
//
//  Created by El-Mundo on 26/06/2024.
//

import SwiftUI

struct TableAttributeIdentified: Identifiable {
    var name: String
    var id = UUID()
}

struct FaceNetworkTable: View {
    @State private var faces = [TableFace]()
    @State var networkAttributes = [TableAttributeIdentified]()
    @State private var selectedFaces = Set<TableFace.ID>()
    
    @State var editedString: Binding<String>?
    @State var preEditionString: String?
    @State var editedFace: TableFace?
    @State var editedAttribute: Binding<String>?
    
    @State var scrollOffset: CGFloat = 0
    let cellWidth: CGFloat = 128
    
    var network: FaceNetwork
    var context: Overview
    
    var body: some View {
        let columns = (network.attributes.count + 7)
        let vw = CGFloat(CGFloat(columns) * cellWidth)
        
        List {
            HStack {
                ForEach(networkAttributes) { column in
                    Text(column.name).frame(width: cellWidth)
                }
            }.padding(.leading, self.scrollOffset).frame(height: 12)
        }.frame(height: 32).scrollDisabled(true)
        
        List(selection: $selectedFaces) {
            ForEach(faces, id: \.id) { row in
                TableRowView(row: row, parent: self).padding(.leading, self.scrollOffset)
            }
        }.onAppear(perform: {
            for face in network.faces {
                faces.append(TableFace(face: face))
            }
            for attribute in network.attributes {
                networkAttributes.append(TableAttributeIdentified(name: FA_PreservedFields[5]))
                networkAttributes.append(TableAttributeIdentified(name: FA_PreservedFields[0]))
                networkAttributes.append(TableAttributeIdentified(name: FA_PreservedFields[1]))
                networkAttributes.append(TableAttributeIdentified(name: FA_PreservedFields[3]))
                networkAttributes.append(TableAttributeIdentified(name: FA_PreservedFields[6]))
                networkAttributes.append(TableAttributeIdentified(name: FA_PreservedFields[4]))
                networkAttributes.append(TableAttributeIdentified(name: attribute.name))
            }
        }).onChange(of: selectedFaces) {
            context.selectedFaces.removeAll()
            for face in selectedFaces {
                let f = faces.first { $0.id == face}
                context.selectedFaces.append(f!)
            }
        }
        
        ScrollView(.horizontal, showsIndicators: false) {
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(.white)
                        .frame(width: vw)
                    let barWidth = context.tableWidth / vw * context.tableWidth
                    RoundedRectangle(cornerSize: CGSize(width: 6, height: 6))
                        .fill(.gray)
                        .frame(width: barWidth)
                        .position(x: -scrollOffset/(vw-context.tableWidth)*(context.tableWidth-barWidth)-scrollOffset+barWidth*0.5, y: 6)
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            self.scrollOffset = proxy.frame(in: .global).minX
                        }
                        .onChange(of: proxy.frame(in: .global).minX) {
                            self.scrollOffset = proxy.frame(in: .global).minX
                        }
                    }
                )
            }
            .frame(width: vw, height: 12)
            .gesture(
                DragGesture().onChanged { gesture in
                    if(context.tableWidth < vw) {
                        let barWidth = context.tableWidth / vw * context.tableWidth
                        var norm = (gesture.location.x-barWidth*0.5)/(context.tableWidth - barWidth)
                        norm = max(0, min(1, norm))
                        scrollOffset = (-norm) * (vw - context.tableWidth)
                    } else {
                        scrollOffset = 0
                    }
                }
            )
        }
        
        VStack {
            if(editedString != nil) {
                Text("Editing \(editedAttribute!.wrappedValue) of \(editedFace!.path)").lineLimit(1)
                TextField("", text: editedString!)
                    .onSubmit {
                        let updated = editedFace?.requestUpdate(for: editedAttribute!.wrappedValue, newValue: editedString!.wrappedValue)
                        if((updated ?? false) == false) {
                            editedString = Binding($preEditionString)
                        } else {
                            editedString = nil
                        }
                    }
            }
        }.frame(minWidth: 128, maxWidth: .infinity, minHeight: 48, maxHeight: 48)
    }
    
    struct TableRowView: View {
        @State var row: TableFace
        @State var parent: FaceNetworkTable

        var body: some View {
            HStack {
                Text(row.frame).frame(width: parent.cellWidth).lineLimit(1)
                Text(row.faceBox).frame(width: parent.cellWidth).lineLimit(1)
                Text(row.confidence).frame(width: parent.cellWidth).lineLimit(1)
                Text(row.faceRotation).frame(width: parent.cellWidth).lineLimit(1)
                Text(row.path).frame(width: parent.cellWidth).lineLimit(1)
                Text(row.cluster).frame(width: parent.cellWidth).lineLimit(1)

                // Add more fields as needed
                ForEach($row.attributes) { att in
                    Text(att.wrappedValue.content).frame(width: parent.cellWidth).lineLimit(1)
                        .onTapGesture(count: 2, perform: {
                            parent.editedFace = row
                            parent.editedString = att.content
                            parent.editedAttribute = att.key
                            parent.preEditionString = att.content.wrappedValue
                        })
                }
            }
        }
    }
    
    private mutating func loadNetwork() {
        guard let network = MediaManager.instance!.getEditFaceNetwork() else {
            return
        }
        //self.network = network
        for face in network.faces {
            self.faces.append(TableFace(face: face))
        }
    }
}

/*#Preview {
    FaceNetworkTable()
}*/
