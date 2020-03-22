//
//  DTQuickComicCommon.m
//  QuickComic
//
//  Created by Alexander Rauchfuss on 11/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "DTQuickComicCommon.h"
#import "TSSTSortDescriptor.h"
#import <XADMaster/XADArchive.h>


static NSArray * fileNameSort = nil;


NSMutableArray * fileListForArchive(XADArchive * archive)
{
	NSMutableArray * fileDescriptions = [NSMutableArray array];
	
    NSDictionary * fileDescription;
    int count = [archive numberOfEntries];
    int index = 0;
    NSString * fileName;
	NSString * rawName;
    for ( ; index < count; ++index)
    {
        fileName = [archive nameOfEntry: index];
		XADPath * dataString = [archive rawNameOfEntry: index];
		rawName = [dataString stringWithEncoding: NSNonLossyASCIIStringEncoding];
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[fileName pathExtension], nil);
        [(NSString *)uti autorelease];
        if([[NSImage imageTypes] containsObject: (NSString *)uti])
        {
            fileDescription = [NSDictionary dictionaryWithObjectsAndKeys: fileName, @"name",
                               [NSNumber numberWithInt: index], @"index",
							   rawName, @"rawName", nil];
            [fileDescriptions addObject: fileDescription];
        }
    }
    return [[fileDescriptions retain] autorelease];
}


NSArray * fileSort(void)
{
    if(!fileNameSort)
    {
        TSSTSortDescriptor * sort = [[TSSTSortDescriptor alloc] initWithKey: @"name" ascending: YES];
        fileNameSort = [[NSArray alloc] initWithObjects: sort, nil];
        [sort release];
    }
    
    return fileNameSort;
}

