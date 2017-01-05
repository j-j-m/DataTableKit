//
//  FetchedResultTableDirector.swift
//  Pods
//
//  Created by Jacob Martin on 12/26/16.
//
//

import UIKit
//import AWSCore
//import APIModule
//import BaseModule
//import SkeletonModule
//import GraphicsModule
import CoreData


//struct ActionType<A> {
//   static func action
//}

/**
 Responsible for table view's datasource and delegate.
 */

/// Protocol for to assure models can be used with this tabledirector and generate their own row models


public protocol DataTableDirectorConforming {
    func row(_ type:String) -> (action: () -> ()) -> Row
}


public class FetchedResultTableDirector<T:DataTableDirectorConforming>: NSObject, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    
    public private(set) weak var tableView: UITableView?
    public private(set) var sections = [TableSection]()
    
    private weak var scrollDelegate: UIScrollViewDelegate?
    private var heightStrategy: CellHeightCalculatable?
    private var cellRegisterer: TableCellRegisterer?
    
    //assume there will always be a data section
    private var sectionCount:Int = 1
    private var dataSectionIndex:Int = 0
    
    public var rowType:String = ""
    
    public var dataSectionHeader: UIView?
    public var dataSectionHeaderTitle: String?
    public var dataSectionHeaderHeight: CGFloat? = 0
    
    public var dataSectionFooter: UIView?
    public var dataSectionFooterTitle: String?
    public var dataSectionFooterHeight: CGFloat? = 0
    
    var sectionsBefore:[TableSection]?
    var sectionsAfter:[TableSection]?
    
    
    
    
    
    //set a default prototype action
    var protoTypeAction:(T) -> () -> () = { frame in
        
        return { _ in
            //print(frame.email!)
            print("cell selected")
        }
    }
    
    public var shouldUsePrototypeCellHeightCalculation: Bool = false {
        didSet {
            if shouldUsePrototypeCellHeightCalculation {
                heightStrategy = PrototypeHeightStrategy(tableView: tableView)
            }
        }
    }
    
    public var isEmpty: Bool {
        return sections.isEmpty
    }
    

    
   public  var fetchedResultsController : NSFetchedResultsController? {
        didSet {
            assert(NSThread.isMainThread())
            weak var weakSelf = self
            if let c = fetchedResultsController {
                c.delegate = self
                do {
                    try c.performFetch()
                    
                    
                } catch {
                    print("An error occurred")
                }
            }
        }
    }
    
    
    public  var predicate : NSPredicate?
    public var predicateChangeCompletion: (() -> ())?
    
    func refreshPredicate(predicate:NSPredicate, completion:(() -> ())?){
        fetchedResultsController?.fetchRequest.predicate = predicate
        print(fetchedResultsController?.fetchRequest.predicate)
        print(predicate)
        
        refreshFetchedResults(completion)

    }
    
    func refreshFetchedResults(completion: (() -> ())? = nil){
        weak var weakSelf = self
        if let c = weakSelf!.fetchedResultsController {
            c.delegate = self
            do {
                try c.performFetch()
                
                //why I have to call weakSelf?.reload() I dont know yet. but I need to in order to prevent crashes on creation and delete of reference object. interesting
                weakSelf?.reload()
                predicateChangeCompletion = { _ in
                    weakSelf?.reload()
                    completion?()
                }
                
            } catch {
                print("An error occurred")
            }
        }
    }
    
    
    // get prototype row for indexpath
    func tableRowForIndexPath(indexPath:NSIndexPath) -> Row {
        
//        offset section to reference fetched results controller
       
        if indexPath.section == dataSectionIndex {
            var alteredIndex = NSIndexPath(forRow: indexPath.row, inSection: 0)
            
            guard let selectedObject = fetchedResultsController!.objectAtIndexPath(alteredIndex) as? T else { fatalError("Unexpected Object in FetchedResultsController") }
            
             return selectedObject.row(rowType)(action:protoTypeAction(selectedObject))
        }
        else if indexPath.section < dataSectionIndex {
            return sectionsBefore![indexPath.section].rows[indexPath.row]
        }
        else {
            return sectionsAfter![indexPath.section - dataSectionIndex - 1].rows[indexPath.row]
        }
       
    }
    
    func getSectionAtIndex(index:Int) -> TableSection{
        if index < dataSectionIndex {
            return sectionsBefore![index]
        }
        else {
            return sectionsAfter![index - dataSectionIndex - 1]
        }
    }
    
    public init(tableView: UITableView,
                fetchedResultsController: NSFetchedResultsController,
                rowType:String = "",
                prototypeAction:((T) -> () -> ())? = nil,
                sectionsBefore:[TableSection]? = nil,
                sectionsAfter:[TableSection]? = nil,
        scrollDelegate: UIScrollViewDelegate? = nil,
        shouldUseAutomaticCellRegistration: Bool = true) {
        
        super.init()
        
        // set up section data and indices
        
        self.rowType = rowType
        
        if let sectionsBefore = sectionsBefore {
            self.sectionsBefore = sectionsBefore
            sectionCount = sectionsBefore.count + 1
            dataSectionIndex = sectionsBefore.count
        }
        if let sectionsAfter = sectionsAfter {
            self.sectionsAfter = sectionsAfter
            sectionCount = sectionsAfter.count + 1
            if let sectionsBefore = sectionsBefore {
                sectionCount = sectionsBefore.count + sectionsAfter.count + 1
                dataSectionIndex = sectionsBefore.count
            }
            else {
                dataSectionIndex = 0
            }
            
        }
        
        protoTypeAction = prototypeAction!
        
        
        
        if shouldUseAutomaticCellRegistration {
            self.cellRegisterer = TableCellRegisterer(tableView: tableView)
        }
        
        self.scrollDelegate = scrollDelegate
        self.tableView = tableView
        self.tableView?.delegate = self
        self.tableView?.dataSource = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didReceiveAction), name: TableKitNotifications.CellAction, object: nil)
        
        self.fetchedResultsController = fetchedResultsController
        refreshFetchedResults()
    

    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public func reload() {
        dispatch_async(dispatch_get_main_queue(),{
            self.tableView?.reloadData()
        })
    }
    
    // MARK: Public
    
    public func invoke(action action: TableRowActionType, cell: UITableViewCell?, indexPath: NSIndexPath) -> Any? {
        
        return tableRowForIndexPath(indexPath).invoke(action, cell: cell, path: indexPath)
    
    }
    
    public override func respondsToSelector(selector: Selector) -> Bool {
        return super.respondsToSelector(selector) || scrollDelegate?.respondsToSelector(selector) == true
    }
    
    public override func forwardingTargetForSelector(selector: Selector) -> AnyObject? {
        return scrollDelegate?.respondsToSelector(selector) == true ? scrollDelegate : super.forwardingTargetForSelector(selector)
    }
    
    // MARK: - Internal -
    
    func hasAction(action: TableRowActionType, atIndexPath indexPath: NSIndexPath) -> Bool {
        return tableRowForIndexPath(indexPath).hasAction(action)
    }
    
    func didReceiveAction(notification: NSNotification) {
        
        guard let action = notification.object as? TableCellAction, indexPath = tableView?.indexPathForCell(action.cell) else { return }
        invoke(action: .custom(action.key), cell: action.cell, indexPath: indexPath)
    }
    
    // MARK: - Height
    
    public func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
       
        
        var row = tableRowForIndexPath(indexPath)
    
        cellRegisterer?.register(cellType: row.cellType, forCellReuseIdentifier: row.reuseIdentifier)
        return row.estimatedHeight ?? heightStrategy?.estimatedHeight(row, path: indexPath) ?? UITableViewAutomaticDimension
    }
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        let row = tableRowForIndexPath(indexPath)
        
        let rowHeight = invoke(action: .height, cell: nil, indexPath: indexPath) as? CGFloat
        
        return rowHeight ?? row.defaultHeight ?? heightStrategy?.height(row, path: indexPath) ?? UITableViewAutomaticDimension
    }
    
    // MARK: UITableViewDataSource - configuration
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
       
        
        return sectionCount
    }
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      
        if section == dataSectionIndex {
            if let fetchedResultsController = fetchedResultsController {
                guard let sections = fetchedResultsController.sections
                    else{
                return 0
                }
                if sections.count > 0 {
                    let sectionInfo = sections[0]
             //   print(sectionInfo.numberOfObjects)
                return sectionInfo.numberOfObjects
                }
                else{
                    return 0
                }
            }
            else {
               return 0 
            }
            
           
        }
        else if section < dataSectionIndex  {
         //   print(sectionsBefore?.count)
            return (sectionsBefore != nil) ? sectionsBefore![section].rows.count : 0
        }
        else {
            return (sectionsAfter != nil) ? sectionsAfter![section - dataSectionIndex - 1].rows.count : 0
        }
    }
    
    
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
       
        
        var row: Row?
        if(indexPath.section == dataSectionIndex){
            var alteredIndex = NSIndexPath(forRow: indexPath.row, inSection: 0)
             guard let selectedObject = fetchedResultsController!.objectAtIndexPath(alteredIndex) as? T else { fatalError("Unexpected Object in FetchedResultsController") }
        
           // let model:StringCellModel = ("Photo Frame \(indexPath.row + 1)", .Checkmark)
        
             row = selectedObject.row(rowType)(action:protoTypeAction(selectedObject))
        }
        else {
            row = tableRowForIndexPath(indexPath)
        }
        
        let cell = tableView.dequeueReusableCellWithIdentifier(row!.reuseIdentifier, forIndexPath: indexPath)
        
        if cell.frame.size.width != tableView.frame.size.width {
            cell.frame = CGRectMake(0, 0, tableView.frame.size.width, cell.frame.size.height)
            cell.layoutIfNeeded()
        }
        
        row!.configure(cell)
        invoke(action: .configure, cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    // MARK: UITableViewDataSource - section setup
    
    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if(section == dataSectionIndex){
            return dataSectionHeaderTitle
        }
        let s = getSectionAtIndex(section)
        return s.headerTitle
    }
    
    public func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {

        if(section == dataSectionIndex){
            return dataSectionFooterTitle
        }
        let s = getSectionAtIndex(section)
        return s.footerTitle
    }
    
    // MARK: UITableViewDelegate - section setup
    
    public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if(section == dataSectionIndex){
            return dataSectionHeader
        }
        let s = getSectionAtIndex(section)
        return s.headerView
    }
    
    public func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if(section == dataSectionIndex){
            return dataSectionFooter
        }
        let s = getSectionAtIndex(section)
        return s.footerView
    }
    
    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    
        if(section == dataSectionIndex){
            return dataSectionHeader?.bounds.size.height ??  dataSectionHeaderHeight ?? 0
        }
        let s = getSectionAtIndex(section)
        return s.headerHeight ?? s.headerView?.frame.size.height ?? 0
    }
    
    public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        if(section == dataSectionIndex){
            return dataSectionFooter?.bounds.size.height ??  dataSectionFooterHeight ?? 0
        }
        let s = getSectionAtIndex(section)
        return s.footerHeight ?? s.footerView?.frame.size.height ?? 0
        
    }
    
    // MARK: UITableViewDelegate - actions
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let cell = tableView.cellForRowAtIndexPath(indexPath)
        
        if invoke(action: .click, cell: cell, indexPath: indexPath) != nil {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        } else {
            invoke(action: .select, cell: cell, indexPath: indexPath)
        }
    }
    
    public func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        invoke(action: .deselect, cell: tableView.cellForRowAtIndexPath(indexPath), indexPath: indexPath)
    }
    
    public func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        invoke(action: .willDisplay, cell: cell, indexPath: indexPath)
    }
    
    public func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return invoke(action: .shouldHighlight, cell: tableView.cellForRowAtIndexPath(indexPath), indexPath: indexPath) as? Bool ?? true
    }
    
    public func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        
        if hasAction(.willSelect, atIndexPath: indexPath) {
            return invoke(action: .willSelect, cell: tableView.cellForRowAtIndexPath(indexPath), indexPath: indexPath) as? NSIndexPath
        }
        return indexPath
    }
    
    // MARK: - Row editing -
    
    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
    
    public func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        return sections[indexPath.section].rows[indexPath.row].editingActions
    }
    
    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        if editingStyle == .Delete {
            invoke(action: .clickDelete, cell: tableView.cellForRowAtIndexPath(indexPath), indexPath: indexPath)
        }
    }
    
    // MARK: - Sections manipulation -
    
    public func append(section section: TableSection) -> Self {
        
        append(sections: [section])
        return self
    }
    
    public func append(sections sections: [TableSection]) -> Self {
        
        self.sections.appendContentsOf(sections)
        return self
    }
    
    public func append(rows rows: [Row]) -> Self {
        
        append(section: TableSection(rows: rows))
        return self
    }
    
    public func insert(section section: TableSection, atIndex index: Int) -> Self {
        
        sections.insert(section, atIndex: index)
        return self
    }
    
    public func delete(index index: Int) -> Self {
        
        sections.removeAtIndex(index)
        return self
    }
    
    public func clear() -> Self {
        
        sections.removeAll()
        return self
    }
    
    
    
    
    
    
    
 //MARK: - NSFetchedResultsControllerDelegate
    
   
    
    public func controllerWillChangeContent(controller: NSFetchedResultsController) {
        //        self.tableView!.beginUpdates()
    }
    
    public func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
    }
    
    public func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
    }
    
    public func controllerDidChangeContent(controller: NSFetchedResultsController) {
        weak var weakSelf = self
        dispatch_async(dispatch_get_main_queue()) {
            
            self.predicateChangeCompletion?()
            
            self.reload()
            
            self.predicateChangeCompletion = nil
            //self.tableView!.endUpdates()
        }
    }
    
    
    
}




 
 
