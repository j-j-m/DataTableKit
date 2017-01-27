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
    func row(type:String) -> (() -> ()) -> Row
}


public class FetchedResultTableDirector<T:DataTableDirectorConforming>: NSObject, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    
    open private(set) weak var tableView: UITableView?
    open fileprivate(set) var sections = [TableSection]()
    
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
    
    open var isEmpty: Bool {
        return sections.isEmpty
    }
    

    
   public  var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>? {
        didSet {
            assert(Thread.isMainThread)
           
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
    
    public func refreshPredicate(predicate:NSPredicate, completion:(() -> ())?){
        fetchedResultsController?.fetchRequest.predicate = predicate
        print(fetchedResultsController?.fetchRequest.predicate)
        print(predicate)
        
        refreshFetchedResults(completion: completion)

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
    func tableRowForIndexPath(indexPath:IndexPath) -> Row {
        
//        offset section to reference fetched results controller
       
        if indexPath.section == dataSectionIndex {
            let alteredIndex = IndexPath(row: indexPath.row, section: 0)
            
            guard let selectedObject = fetchedResultsController!.object(at: alteredIndex) as? T else { fatalError("Unexpected Object in FetchedResultsController") }
            
             return selectedObject.row(type: rowType)(protoTypeAction(selectedObject))
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
                fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>,
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveAction), name: NSNotification.Name(rawValue: TableKitNotifications.CellAction), object: nil)
        
        self.fetchedResultsController = fetchedResultsController
        refreshFetchedResults()
    

    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    open func reload() {
       DispatchQueue.main.async {
            self.tableView?.reloadData()
        }
    }
    
    // MARK: Public
    
    @discardableResult
    open func invoke(action: TableRowActionType, cell: UITableViewCell?, indexPath: IndexPath, userInfo: [AnyHashable: Any]? = nil) -> Any? {

        
        return tableRowForIndexPath(indexPath: indexPath).invoke(action: action, cell: cell, path: indexPath, userInfo: userInfo)
    
    }
    
    open override func responds(to selector: Selector) -> Bool {
        return super.responds(to:selector) || scrollDelegate?.responds(to: selector) == true
    }
    
    open override func forwardingTarget(for selector: Selector) -> Any? {
        return scrollDelegate?.responds(to: selector) == true ? scrollDelegate : super.forwardingTarget(for: selector)
    }
    
    // MARK: - Internal -
    
    func hasAction(_ action: TableRowActionType, atIndexPath indexPath: IndexPath) -> Bool {
        return tableRowForIndexPath(indexPath: indexPath).has(action:action)
    }
    
    func didReceiveAction(_ notification: Notification) {
        
        guard let action = notification.object as? TableCellAction, let indexPath = tableView?.indexPath(for: action.cell) else { return }
        invoke(action: .custom(action.key), cell: action.cell, indexPath: indexPath)
    }
    
    // MARK: - Height
    
    open func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let row = tableRowForIndexPath(indexPath: indexPath)
    
        cellRegisterer?.register(cellType: row.cellType, forCellReuseIdentifier: row.reuseIdentifier)
        return row.estimatedHeight ?? heightStrategy?.estimatedHeight(row: row, path: indexPath as NSIndexPath) ?? UITableViewAutomaticDimension
    }
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let row = tableRowForIndexPath(indexPath: indexPath)
        
        let rowHeight = invoke(action: .height, cell: nil, indexPath: indexPath) as? CGFloat
        
        return rowHeight ?? row.defaultHeight ?? heightStrategy?.height(row: row, path: indexPath as NSIndexPath) ?? UITableViewAutomaticDimension
    }
    
    // MARK: UITableViewDataSource - configuration
    
    open func numberOfSections(in tableView: UITableView) -> Int {
       
        
        return sectionCount
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      
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
    
    
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
       
        
        var row: Row?
        if(indexPath.section == dataSectionIndex){
            let alteredIndex = NSIndexPath(row: indexPath.row, section: 0)
             guard let selectedObject = fetchedResultsController!.object(at: alteredIndex as IndexPath) as? T else { fatalError("Unexpected Object in FetchedResultsController") }
        
           // let model:StringCellModel = ("Photo Frame \(indexPath.row + 1)", .Checkmark)
        
             row = selectedObject.row(type: rowType)(protoTypeAction(selectedObject))
        }
        else {
            row = tableRowForIndexPath(indexPath: indexPath)
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: row!
            
            
            
            .reuseIdentifier, for: indexPath)
        
        if cell.frame.size.width != tableView.frame.size.width {
            cell.frame = CGRect(x:0, y:0, width:tableView.frame.size.width, height:cell.frame.size.height)
            cell.layoutIfNeeded()
        }
        
        row!.configure(cell)
        invoke(action: .configure, cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    // MARK: UITableViewDataSource - section setup
    
    open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if(section == dataSectionIndex){
            return dataSectionHeaderTitle
        }
        let s = getSectionAtIndex(index: section)
        return s.headerTitle
    }
    
    open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {

        if(section == dataSectionIndex){
            return dataSectionFooterTitle
        }
        let s = getSectionAtIndex(index: section)
        return s.footerTitle
    }
    
    // MARK: UITableViewDelegate - section setup
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if(section == dataSectionIndex){
            return dataSectionHeader
        }
        let s = getSectionAtIndex(index: section)
        return s.headerView
    }
    
    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if(section == dataSectionIndex){
            return dataSectionFooter
        }
        let s = getSectionAtIndex(index: section)
        return s.footerView
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    
        if(section == dataSectionIndex){
            return dataSectionHeader?.bounds.size.height ??  dataSectionHeaderHeight ?? 0
        }
        let s = getSectionAtIndex(index: section)
        return s.headerHeight ?? s.headerView?.frame.size.height ?? 0
    }
    
    open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        if(section == dataSectionIndex){
            return dataSectionFooter?.bounds.size.height ??  dataSectionFooterHeight ?? 0
        }
        let s = getSectionAtIndex(index: section)
        return s.footerHeight ?? s.footerView?.frame.size.height ?? 0
        
    }
    
    // MARK: UITableViewDelegate - actions
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath)
        
        if invoke(action: .click, cell: cell, indexPath: indexPath) != nil {
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            invoke(action: .select, cell: cell, indexPath: indexPath)
        }
    }
    
    open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        invoke(action: .deselect, cell: tableView.cellForRow(at: indexPath), indexPath: indexPath)
    }
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        invoke(action: .willDisplay, cell: cell, indexPath: indexPath)
    }
    
    open func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return invoke(action: .shouldHighlight, cell: tableView.cellForRow(at: indexPath), indexPath: indexPath) as? Bool ?? true
    }
    
    open func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        
        if hasAction(.willSelect, atIndexPath: indexPath) {
            return invoke(action: .willSelect, cell: tableView.cellForRow(at: indexPath), indexPath: indexPath) as! IndexPath?
        }
        return indexPath
    }
    
    // MARK: - Row editing -
    
    open func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    open func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return sections[indexPath.section].rows[indexPath.row].editingActions
    }
    
    open func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            invoke(action: .clickDelete, cell: tableView.cellForRow(at: indexPath), indexPath: indexPath)
        }
    }
    
    // MARK: - Sections manipulation -
    
    @discardableResult
    open func append(section: TableSection) -> Self {
        
        append(sections: [section])
        return self
    }
    
    @discardableResult
    open func append(sections: [TableSection]) -> Self {
        
        self.sections.append(contentsOf: sections)
        return self
    }
    
    @discardableResult
    open func append(rows: [Row]) -> Self {
        
        append(section: TableSection(rows: rows))
        return self
    }
    
    @discardableResult
    open func insert(section: TableSection, atIndex index: Int) -> Self {
        
        sections.insert(section, at: index)
        return self
    }
    
    @discardableResult
    open func delete(sectionAt index: Int) -> Self {
        
        sections.remove(at: index)
        return self
    }
    
    @discardableResult
    open func clear() -> Self {
        
        sections.removeAll()
        return self
    }
    
    
    
    
    
    
    
 //MARK: - NSFetchedResultsControllerDelegate
    
   
    
    public func controllerWillChangeContent(controller: NSFetchedResultsController<NSFetchRequestResult>) {
        //        self.tableView!.beginUpdates()
    }
    
    public func controller(controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
    }
    
    public func controller(controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
    }
    
    public func controllerDidChangeContent(controller: NSFetchedResultsController<NSFetchRequestResult>) {

        DispatchQueue.main.async {
            
            self.predicateChangeCompletion?()
            
            self.reload()
            
            self.predicateChangeCompletion = nil
            //self.tableView!.endUpdates()
        }
    }
    
    
    
}




 
 
