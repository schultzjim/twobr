//
//  ViewController.swift
//  Twobr
//
//  Created by Jim Schultz on 2/9/15.
//  Copyright (c) 2015 Blue Boxen, LLC. All rights reserved.
//

import UIKit
import Social
import Accounts

let defaultAvatarURL = NSURL(string: "https://abs.twimg.com/sticky/default_profile_images/default_profile_6_200x200.png")

class JobsViewController: UITableViewController, TwitterAPIRequestDelegate {
    
    var jobDetailsVC: JobDetailsViewController? = nil
    var sinceID: String? = nil
    var matchedTweets: [ParsedTweet] = []
    
    @IBAction func handleTweetButtonTapped(sender: AnyObject) {
        if SLComposeViewController.isAvailableForServiceType(SLServiceTypeTwitter) {
            let tweetVC = SLComposeViewController(forServiceType: SLServiceTypeTwitter)
            tweetVC.setInitialText("Hey tweoples, i'll looking for a new job, if you know of something give me a shout. #twobr")
            presentViewController(tweetVC, animated: true, completion: nil)
        } else {
            println("can't send tweet")
        }
    }
    
    @IBAction func handleRefresh(sender : AnyObject?) {
        self.reloadTweets()
        refreshControl!.endRefreshing()
    }
    
    func reloadTweets() {
        let accountStore = ACAccountStore()
        let twitterAccountType = accountStore.accountTypeWithAccountTypeIdentifier(ACAccountTypeIdentifierTwitter)
        accountStore.requestAccessToAccountsWithType(twitterAccountType, options: nil, completion: {
            (granted: Bool, error: NSError!) -> Void in
            if !granted {
                println("account access not granted")
            } else {
                let twitterAccounts = accountStore.accountsWithAccountType(twitterAccountType)
                if twitterAccounts.count == 0 {
                    println("no twitter accounts configured")
                } else {
                    var twitterParams = ["count":"100"]
                    if self.sinceID != nil {
                        twitterParams["since_id"] = self.sinceID
                    }
                    
                    let twitterAPIURL = NSURL(string: "https://api.twitter.com/1.1/statuses/home_timeline.json")
                    let request = TwitterAPIRequest()
                    request.sendTwitterRequest(twitterAPIURL, params: twitterParams, delegate: self)
                }
            }
        })
    }
    
    func handleTwitterData(data: NSData!, urlResponse: NSHTTPURLResponse!, error: NSError!, fromRequest: TwitterAPIRequest!) {
        if let dataValue = data {
            var parseError: NSError? = nil
            let jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(dataValue, options: NSJSONReadingOptions(0), error: &parseError)
            if parseError != nil {
                return
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {
                if let jsonArray = jsonObject as? [[String:AnyObject]] {
                    for tweetDict in jsonArray {
                        //println("tweet: \(tweetDict)")
                        //let keywords = ["open", "available", "fill", "work", "job", "hire", "hiring", "career", "look", "need", "position", "search", "find", "help", "grow", "join", "apply", "application", "full-time", "part-time", "full time", "part time", "contractor", "freelance"]
                        let keywords = ["job", "career", "hire", "hiring", "find", "looking", "part-time", "full-time", "part time", "full time", "position", "twobr", "post"]
                        
                        var score = 0
                        let scoreToBeat = 1
                        if let text = tweetDict["text"] as? String {
                            for keyword in keywords {
                                if text.lowercaseString.rangeOfString(keyword) != nil {
                                    score += 1
                                }
                                if score > scoreToBeat { break }
                            }
                        }
                        
                        if let retweetedStatus = tweetDict["retweeted_status"] as? [String:AnyObject] {
                            if let entities = retweetedStatus["entities"] as? [String:AnyObject] {
                                if let hashtags = entities["hashtags"] as? [[String:AnyObject]] {
                                    for hashtag in hashtags {
                                        if let text = hashtag["text"] as? String {
                                            for keyword in keywords {
                                                if text.lowercaseString.rangeOfString(keyword) != nil {
                                                    score += 1
                                                }
                                                if score > scoreToBeat { break }
                                            }
                                        }
                                    }
                                }
                                if let urls = entities["urls"] as? [[String:AnyObject]] {
                                    for urlDict in urls {
                                        if let url = urlDict["display_url"] as? String {
                                            for keyword in keywords {
                                                if url.lowercaseString.rangeOfString(keyword) != nil {
                                                    score += 1
                                                }
                                                if score > scoreToBeat { break }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        if score > scoreToBeat {
                            let parsedTweet = ParsedTweet()
                            parsedTweet.tweetIdString = tweetDict["id_str"] as? String
                            parsedTweet.tweetText = tweetDict["text"] as? String
                            parsedTweet.createdAt = tweetDict["created_at"] as? String
                            let userDict = tweetDict["user"] as NSDictionary
                            parsedTweet.userName = userDict["name"] as? String
                            parsedTweet.userAvatarURL = NSURL(string: userDict["profile_image_url"] as String!)
                            self.matchedTweets.append(parsedTweet)
                        }
                    }
                    if jsonArray.count > 0 {
                        self.sinceID = jsonArray[0]["id_str"] as? String
                    }
                    dispatch_async(dispatch_get_main_queue(), {
                        self.tableView.reloadData()
                    })
                } else {
                    println("json: \(jsonObject)")
                }
            })
        } else {
            println("handleTwitterData recieved no data")
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.jobDetailsVC = controllers[controllers.count-1].topViewController as? JobDetailsViewController
        }
        
        reloadTweets()
        var refresher = UIRefreshControl()
        refresher.addTarget(self, action: "handleRefresh:", forControlEvents: UIControlEvents.ValueChanged)
        refreshControl = refresher
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showJobDetailsSegue" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                let parsedTweet = matchedTweets[indexPath.row] as ParsedTweet
                let controller = (segue.destinationViewController as UINavigationController).topViewController as JobDetailsViewController
                controller.tweetIdString = parsedTweet.tweetIdString
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // UITableViewDelegate UITableViewDataSource
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchedTweets.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ParsedTweetCell") as ParsedTweetCell
        let parsedTweet = matchedTweets[indexPath.row]
        cell.userNameLabel.text = parsedTweet.userName
        cell.tweetTextLabel.text = parsedTweet.tweetText
        cell.createdAtLabel.text = parsedTweet.createdAt
        if parsedTweet.userAvatarURL != nil {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                if let imageData = NSData(contentsOfURL: parsedTweet.userAvatarURL!) {
                    let avatarImage = UIImage(data: imageData)
                    dispatch_async(dispatch_get_main_queue(), {
                        if cell.userNameLabel.text == parsedTweet.userName {
                            cell.avatarImageView.image = avatarImage
                        } else {
                            println("oops, wrong cell, never mind")
                        }
                    })
                }
            })
        }
        return cell
    }
}

