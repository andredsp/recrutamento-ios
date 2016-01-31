//
//  ViewController.swift
//  TraktDemo
//
//  Created by André Pinto on 30/01/16.
//  Copyright © 2016 André Pinto. All rights reserved.
//

import UIKit
import OAuthSwift

class ViewController: UIViewController, UICollectionViewDataSource {
    typealias Show = (title:String?, image:String?)
    
    // Views
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var showsCollection: UICollectionView!
    var refreshControl:UIRefreshControl!

    // Model
    var shows = [Show]()
    var authorized = false
    let oauthswift = OAuth2Swift(
        consumerKey:    "8fd9163f5955a30b2a01fe19b9bc6113151348c454cc727d234267b8c18a87c4",
        consumerSecret: "47222c45c68d68f81b1f2e29d97124b11f670047196b479e29b6dbdfc0a5721e",
        authorizeUrl:   "https://trakt.tv/oauth/authorize",
        accessTokenUrl: "https://api-v2launch.trakt.tv/oauth/token",
        responseType:   "code"
    )
    
    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Puxe para recarregar")
        self.refreshControl.addTarget(self, action: "getData", forControlEvents: UIControlEvents.ValueChanged)
        
        self.showsCollection.addSubview(refreshControl)
        self.showsCollection.alwaysBounceVertical = true
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshUI()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UI Handling
    
    func refreshUI() {
        showsCollection.hidden = !authorized
        loginButton.hidden = authorized
        if authorized {
            UIView.animateWithDuration(0.2, animations: {
                self.refreshControl.endRefreshing()
                
                }, completion: { (finished: Bool) in
                    self.showsCollection.reloadData()
            })
        }
    }
    
    // MARK: - Service connection

    func authorize() {
        oauthswift.authorize_url_handler = SafariURLHandler(viewController: self)
        oauthswift.authorizeWithCallbackURL(
            NSURL(string: "com.andrepinto.TraktDemo://oauth-callback/traktdemo")!,
            scope: "",
            state: "",
            success: { (credential, response, parameters) in
                print("Authorized! token = \(credential.oauth_token)")
                
                self.authorized = true
                self.refreshUI()
                
                self.getData()
                
            }, failure: {(error:NSError!) -> Void in
                print(error.localizedDescription)
                //                self.presentAlert("Error", message: error!.localizedDescription)
                self.refreshUI()
        })
    }
    
    func logout() {
        print("logout")

    }
    
    func getData() {
        oauthswift.client.request("https://api-v2launch.trakt.tv/shows/popular?extended=images",
            method: .GET,
            headers: [
                "Content-Type": "application/json",
                "trakt-api-version": "2",
                "trakt-api-key": "8fd9163f5955a30b2a01fe19b9bc6113151348c454cc727d234267b8c18a87c4",
            ],
            success: { data, response in
//                let dataString = NSString(data: data, encoding: NSUTF8StringEncoding)
//                print(dataString)
                self.processJSON(data)                
            }
            , failure: { error in
                print(error)
                self.refreshUI()
            }
        )
        
    }
    
    func processJSON(data: NSData) {
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            
            var newList = [Show]()
            for show in json as! NSArray {
                let title = show["title"] as? String
                let image = ((show["images"] as? NSDictionary)? ["poster"] as? NSDictionary)? ["thumb"] as? String
                newList.append((title: title, image: image))
            }
            
            self.shows = newList
            self.refreshUI()

        } catch {
            print("error serializing JSON: \(error)")
        }
    }

    // MARK: - Actions

    @IBAction func doLogin(sender: AnyObject) {
        authorize()
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return shows.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        // Get the cell
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("thumbnail", forIndexPath: indexPath)
        
        // Get the model
        let show = shows[indexPath.row]
        
        // Hook the model to the view
        let imageView = cell.contentView.viewWithTag(10) as! UIImageView
        let titleLabel = cell.contentView.viewWithTag(20) as! UILabel
        titleLabel.text = show.title
        
        imageView.image = nil
        if let imageURL = show.image {
            imageView.downloadedFrom(link: imageURL, contentMode: UIViewContentMode.ScaleAspectFill)
        }
        
        return cell
    }
    
}

// MARK: - Image download

extension UIImageView {
    func downloadedFrom(link link:String, contentMode mode: UIViewContentMode) {
        guard
            let url = NSURL(string: link)
            else {return}
        contentMode = mode
        NSURLSession.sharedSession().dataTaskWithURL(url, completionHandler: { (data, response, error) -> Void in
            guard
                let httpURLResponse = response as? NSHTTPURLResponse where httpURLResponse.statusCode == 200,
                let mimeType = response?.MIMEType where mimeType.hasPrefix("image"),
                let data = data where error == nil,
                let image = UIImage(data: data)
                else { return }
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                self.image = image
            }
        }).resume()
    }
}
