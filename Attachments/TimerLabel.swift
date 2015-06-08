//
//  TimerLabel.swift
//  Attachments
//
//  Created by damingdan on 15/6/8.
//  Copyright (c) 2015年 kingoit. All rights reserved.
//

import UIKit

@objc
public enum TimerLabelType:Int {
    case StopWatch
    case Timer
}

@objc
public protocol TimerLabelDelegate:NSObjectProtocol {
    /**
    TimerLabel Delegate method for finish of countdown timer
    
    :param: timerLabel
    :param: countTime
    */
    func finshedCountDownTimer(timerLabel:TimerLabel, countTime:NSTimeInterval)
    
    /**
    TimerLabel Delegate method for monitering the current counting progress
    
    :param: timerLabel
    :param: timertype
    */
    func counting(timerLabel:TimerLabel, time:NSTimeInterval,  timertype:TimerLabelType)
    
    /**
    TimerLabel Delegate method for overriding the text displaying at the time, implement this for your very custom display formmat
    
    :param: timerLabel
    :param: time
    */
    func customTextToDisplay(timerLabel:TimerLabel, time:NSTimeInterval)->String
}

public class TimerLabel: UILabel {
    /**
    *  Delegate for finish of countdown timer
    */
    public var delegate:TimerLabelDelegate?
    
    /**
    *  Time format wish to display in label
    */
    public var timeFormat:String = "HH:mm:ss" {
        didSet {
            if !self.timeFormat.isEmpty {
                dateFormatter.dateFormat = self.timeFormat
            }
            updateLabel()
        }
    }
    
    /**
    *  Target label obejct, default self if you do not initWithLabel nor set
    */
    private var _timeLabel:UILabel?
    public var timeLabel:UILabel! {
        if self._timeLabel == nil {
            self._timeLabel = self
        }
        return self._timeLabel
    }
    
    /**
    *  Type to choose from stopwatch or timer
    */
    public var timerType = TimerLabelType.StopWatch
    
    /**
    *  Is The Timer Running?
    */
    internal(set) var counting:Bool = false
    
    /**
    *  Do you want to reset the Timer after countdown?
    */
    public var resetTimerAfterFinish:Bool = false
    
    /**
    *  Do you want the timer to count beyond the HH limit from 0-23 e.g. 25:23:12 (HH:mm:ss)
    */
    public var shouldCountBeyondHHLimit:Bool = false {
        didSet {
            updateLabel()
        }
    }
    
    public var endedBlock:((NSTimeInterval)->Void)?
    
    
    private var date1970:NSDate = NSDate(timeIntervalSince1970: 0)
    private var timer:NSTimer?
    private var timeUserValue:NSTimeInterval = 0
    private var startCountDate:NSDate? = NSDate()
    private var pausedTime:NSDate? = NSDate()
    private var timeToCountOff:NSDate = NSDate()
    
    private var dateFormatter:NSDateFormatter  {
        var formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_GB")
        formatter.timeZone = NSTimeZone(name: "GMT")
        formatter.dateFormat = self.timeFormat
        return formatter
    }
    
    //MARK: - Initialize method
    public convenience init(theType:TimerLabelType) {
        self.init(frame:CGRectZero, theLabel:nil, theType:theType)
    }
    
    public convenience init(theLabel:UILabel, theType:TimerLabelType) {
        self.init(frame:CGRectZero, theLabel:theLabel, theType:theType)
    }
    
    public convenience init(theLabel:UILabel) {
        self.init(frame:CGRectZero, theLabel:theLabel, theType:TimerLabelType.Timer)
    }
    
    init(frame: CGRect, theLabel:UILabel?, theType:TimerLabelType) {
        super.init(frame: frame)
        self._timeLabel = theLabel
        self.timerType = theType
        setup()
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    //MARK: - Cleanup
    public override func removeFromSuperview() {
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
        super.removeFromSuperview()
    }
    
    //MARK: - Private method
    private func setup() {
        updateLabel()
    }
    
   
    internal func updateLabel() {
        var timeDiff:NSTimeInterval = 0
        if let date = startCountDate {
            timeDiff =  NSDate().timeIntervalSinceDate(date)
        }
        
        var timeToShow = NSDate()
        var timerEnded = false
        
        
        if timerType == TimerLabelType.StopWatch {
            //TimerLabelTypeStopWatch Logic
            if counting {
                timeToShow = date1970.dateByAddingTimeInterval(timeDiff)
            }else {
                var timeToAdd = (startCountDate != nil) ? NSTimeInterval(0) : timeDiff
                timeToShow = date1970.dateByAddingTimeInterval(timeToAdd)
                delegate?.counting(self, time: timeDiff, timertype: timerType)
            }
        }else {
            // TimerLabelTypeTimer Logic
            if counting {
                var timeLeft = timeUserValue - timeDiff
                delegate?.counting(self, time: timeLeft, timertype: timerType)
                if timeDiff >= timeUserValue {
                    pause()
                    timeToShow = date1970.dateByAddingTimeInterval(0)
                    startCountDate = nil
                    timerEnded = true
                }else {
                    //added 0.999 to make it actually counting the whole first second
                    timeToShow = timeToCountOff.dateByAddingTimeInterval(timeDiff * -1)
                }
            }else {
                timeToShow = timeToCountOff
            }
        }
        
        //setting text value
        var atTime = (timerType == TimerLabelType.StopWatch) ? timeDiff : ((timeUserValue - timeDiff) < 0 ? 0 : (timeUserValue - timeDiff));
        if let customText = delegate?.customTextToDisplay(self, time: atTime) {
            if customText.isEmpty {
                timeLabel.text = dateFormatter.stringFromDate(timeToShow)
            }else {
                timeLabel.text = customText
            }
        }else {
            if shouldCountBeyondHHLimit {
                var originalTimeFormat = timeFormat
                // TODO: API Change
                var beyondFormat = timeFormat.stringByReplacingOccurrencesOfString("HH", withString: "!!!*", options: NSStringCompareOptions.allZeros, range: nil)
                beyondFormat = timeFormat.stringByReplacingOccurrencesOfString("H", withString: "!!!*", options: NSStringCompareOptions.allZeros, range: nil)
                 self.dateFormatter.dateFormat = beyondFormat
                var hours = (timerType == TimerLabelType.StopWatch) ? Int(self.getTimeCounted() / 3600) : Int(self.getTimeRemaining() / 3600)
                var formmattedDate = dateFormatter.stringFromDate(timeToShow)
                var beyondedDate = formmattedDate.stringByReplacingOccurrencesOfString("!!!*", withString: "\(hours)", options: NSStringCompareOptions.allZeros, range: nil)
                timeLabel.text = beyondedDate
                dateFormatter.dateFormat = originalTimeFormat
            }else {
                timeLabel.text = dateFormatter.stringFromDate(timeToShow)
            }
        }
        
        if timerEnded {
            delegate?.finshedCountDownTimer(self, countTime: timeUserValue)
            self.endedBlock?(timeUserValue)
            if resetTimerAfterFinish {
                reset()
            }
        }
        
    }
    
    //MARK: - Public method
    public func start() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        
        timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "updateLabel", userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
        
        if startCountDate == nil {
            startCountDate = NSDate()
            if timerType == TimerLabelType.StopWatch && timeUserValue > 0 {
                startCountDate = startCountDate?.dateByAddingTimeInterval(-timeUserValue)
            }
        }
        if pausedTime != nil {
            if let countedTime = pausedTime?.timeIntervalSinceDate(startCountDate!) {
                startCountDate = NSDate().dateByAddingTimeInterval(-countedTime)
            }
            pausedTime = nil
        }
        counting = true
        timer?.fire()
    }
    
    public func startWithEndingBlock(endedBlock:(NSTimeInterval)->Void) {
        self.endedBlock = endedBlock
        start()
    }
    
    public func reset() {
        pausedTime = nil
        timeUserValue = (timerType == TimerLabelType.StopWatch) ? 0 : timeUserValue
        startCountDate = counting ? NSDate() : nil
        updateLabel()
    }
    
    public func pause() {
        if counting {
            timer?.invalidate()
            timer = nil
            counting = false
            pausedTime = NSDate()
        }
    }
    
    public func setCountDownTime(time:NSTimeInterval) {
        timeUserValue = (time < 0) ? 0 : time;
        timeToCountOff = date1970.dateByAddingTimeInterval(timeUserValue)
        updateLabel()
    }
    
    public func setStopWatchTime(time:NSTimeInterval) {
        timeUserValue = (time < 0) ? 0 : time;
        if timeUserValue > 0 {
            startCountDate = NSDate().dateByAddingTimeInterval(-timeUserValue)
            pausedTime = NSDate()
            updateLabel()
        }
    }
    
    public func setCountDownToDate(date:NSDate) {
        var timeLeft = NSTimeInterval(date.timeIntervalSinceDate(NSDate()))
        if timeLeft > 0 {
            timeUserValue = timeLeft
            timeToCountOff = date1970.dateByAddingTimeInterval(timeLeft)
        }else {
            timeUserValue = 0
            timeToCountOff = date1970.dateByAddingTimeInterval(0)
        }
        updateLabel()
    }
    
    public func addTimeCountedByTime(timeToAdd:NSTimeInterval) {
        if timerType == TimerLabelType.Timer {
            setCountDownTime(timeToAdd + timeUserValue)
        }else if timerType == TimerLabelType.StopWatch {
            var newStartDate = startCountDate?.dateByAddingTimeInterval(-timeToAdd)
            if NSDate().timeIntervalSinceDate(newStartDate!) <= 0 {
                startCountDate = NSDate()
            }else {
                startCountDate = newStartDate
            }
        }
        updateLabel()
    }
    
    public func getTimeCounted()->NSTimeInterval {
        if startCountDate == nil {
            return 0
        }
        var countedTime = NSDate().timeIntervalSinceDate(startCountDate!)
        if pausedTime != nil {
            var pauseCountedTime = NSDate().timeIntervalSinceDate(pausedTime!)
            countedTime -= pauseCountedTime
        }
        return countedTime
    }
    
    public func getTimeRemaining()->NSTimeInterval {
        if timerType == TimerLabelType.Timer {
            return timeUserValue - getTimeCounted()
        }
        return 0
    }
    
    public func getCountDownTime()->NSTimeInterval {
        if timerType == TimerLabelType.Timer {
            return timeUserValue
        }
        return 0
    }
}
