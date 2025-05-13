import SwiftUI

struct SessionView: View {
    @EnvironmentObject var viewModel: SessionViewModel
    @State private var selectedMode: SessionMode = .shared

    var body: some View {
        Group {
            if viewModel.joined {
                TaskListView(
                    sessionCode: viewModel.sessionCode,
                    mode: viewModel.mode
                )
            } else {
                VStack(spacing: 20) {
                    Text("Совместное планирование").font(.title)

                    Picker("Режим", selection: $selectedMode) {
                        Text("Общие задачи").tag(SessionMode.shared)
                        Text("Инд. планы").tag(SessionMode.individual)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)

                    TextField("Код сессии", text: $viewModel.sessionCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        }

                    HStack(spacing: 20) {
                        Button("Создать сессию") {
                            viewModel.createSession(mode: selectedMode)
                        }
                        Button("Присоединиться") {
                            viewModel.joinSession(code: viewModel.sessionCode)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            }
        }
    }
}
