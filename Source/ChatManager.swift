import Foundation
import PusherPlatform

@objc public class ChatManager: NSObject {
    static public let namespace = "chat_api/v1"

    public let app: App
    public internal(set) var userSubscription: PCUserSubscription? = nil

    public var currentUser: PCCurrentUser? {
        get {
            return self.userSubscription?.currentUser
        }
    }

    let userStore: PCGlobalUserStore

    // TODO: Do we need this here? Should it instead just live on the PCCurrentUser?
    public var users: Set<PCUser> {
        get {
            return self.userStore.users
        }
    }

    public var userId: String? = nil

    public init(
        id: String,
        tokenProvider: PPTokenProvider,
        app: App? = nil,
        logger: PPLogger = PPDefaultLogger(),
        baseClient: PPBaseClient? = nil
    ) {
        (tokenProvider as? PCTestingTokenProvider)?.logger = logger
        self.app = app ?? App(id: id, tokenProvider: tokenProvider, client: baseClient, logger: logger)
        self.userStore = PCGlobalUserStore(app: self.app)
    }

    public func addConnectCompletionHandler(completionHandler: @escaping (PCCurrentUser?, Error?) -> Void) {
        guard let userSub = userSubscription else {
            self.app.logger.log("userSubscription is nil so unable to add a connectCompletionHandler", logLevel: .debug)
            return
        }

        userSub.connectCompletionHandlers.append(completionHandler)
    }

    public func connect(
        userId: String,
        delegate: PCChatManagerDelegate,
        completionHandler: @escaping (PCCurrentUser?, Error?) -> Void
    ) {
        // TODO: This is where you would use the tokenProvider (which would need to be stored) to
        // call fetchTokenAndUserId to get the userId so that the developer doesn't need to provide
        // both a tokenProvider and a userId explicitly

        self.userId = userId
        let path = "/\(ChatManager.namespace)/users/\(userId)"

        let subscribeRequest = PPRequestOptions(method: HTTPMethod.SUBSCRIBE.rawValue, path: path)

        var resumableSub = PPResumableSubscription(
            app: self.app,
            requestOptions: subscribeRequest
        )

        self.userSubscription = PCUserSubscription(
            app: self.app,
            resumableSubscription: resumableSub,
            userStore: self.userStore,
            delegate: delegate,
            connectCompletionHandler: { user, error in
                guard let cUser = user else {
                    completionHandler(nil, error)
                    return
                }

                completionHandler(cUser, nil)
            }
        )

        // TODO: Fix this stuff

        self.app.subscribeWithResume(
            with: &resumableSub,
            using: subscribeRequest,
            //            onOpening: onOpening,
            //            onOpen: onOpen,
            //            onResuming: onResuming,
            onEvent: self.userSubscription!.handleEvent,
            onEnd: { statusCode, headers, info in
                print("ENDED")
            },
            onError: { error in
                completionHandler(nil, error)
            }
        )
    }

    //    fileprivate func onUserSubscriptionStateChange(newState: ) {
    //        self.delegate?.userSubscriptionStateChanged(from: <#T##PCUserSubscriptionState#>, to: <#T##PCUserSubscriptionState#>)
    //    }

}
