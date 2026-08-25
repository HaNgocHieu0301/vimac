//
//  KeyboardShortcuts.swift
//  Vimac
//
//  Created by Dexter Leng on 27/2/21.
//  Copyright © 2021 Dexter Leng. All rights reserved.
//

import Cocoa
import RxSwift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let hintMode = Self("hintMode", default: .init(.f, modifiers: [.control]))
    static let scrollMode = Self("scrollMode", default: .init(.j, modifiers: [.control]))
}

class VimacShortcuts {
    static let shared = VimacShortcuts.init()

    func hintModeShortcutActivation() -> Observable<Void> {
        Observable.create { observer in
            KeyboardShortcuts.onKeyUp(for: .hintMode) {
                observer.onNext(Void())
            }
            return Disposables.create()
        }
    }

    func scrollModeShortcutActivation() -> Observable<Void> {
        Observable.create { observer in
            KeyboardShortcuts.onKeyUp(for: .scrollMode) {
                observer.onNext(Void())
            }
            return Disposables.create()
        }
    }
}
